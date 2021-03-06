classdef (Abstract) Simulator < handle
    %SIMULATOR Simulator base class. All of the code that is common between different algorithms
    %should be written here. This includes plotting the paths, reading data from input files, etc.
    
    % Simulation
    properties
        type            % Determines the type of provided data (paths / triangles)
        speedup         % Determines the speedup factor of running the code in real-time.
        file            % Complete path to the .json file.
        triangles       % Array of triangles that form the map
        simData         % Simulation-level parameters / information
        vehicles        % Array of vehicles.
        dT              % The time difference between consecutive timesteps.
        t               % Holds the current time of the simulation
        plotMode        % Determines now the data will be plotted.
        handle          % The handle for plotting vehicle objects
        distances       % The distances between each vehicle (Lower Triangular Matrix)
        mapAxis         % The axis for plotting the map.
        dataAxis        % THe map for plotting vehicle-level data.
    end
    
    properties (Dependent)
        hasAxis         % Determines if there has been a valid axis argument passed to the simulator.
        path1           % The first bounding path.
        path2           % The second bounding path. 
        tEnd            % The latest time that a vehicle can be spawned.
        fSpawn          % The frequency at which vehicles are spawned into the map.
        seed            % The random number seed that allows for reproducability of simulations.
        velocity        % The nominal velocity of the vehicles in the simulation.
        entryEdge       % The edge that the vehicles will enter from.
        exitEdge        % The edge that the vehicles will exit from.
        nVehicles       % The number of vehicles in the simulation
        nTriangles      % The number of triangles in the simulation.
        activeVehicles  % The list of active vehicle indices
        nActiveVehicles % The number of active vehicles in the map.
        avgClosestDist  % Returns the average closest distance between adjacent vehicles.
        avgDist         % Returns the average distance between all vehicles.
        finished        % Flag that contains the completion state of the simulation.
    end
    
    % Logging
    properties
        LOG_PATH                % Path to the current simulation's logging directory.
        TIME_PATH               % Path to the current simulation's time spreadsheet.
        EVENT_PATH              % Path to the curretn simulation's event spreadsheet.
        TIME                    % Records the simulation time
        NUM_ACTIVE_VEHICLES     % Records the number of active vehicles at each time step.
        AVERAGE_CLOSEST_DIST    % Records the average closest distance between adjacent vehicles
        AVERAGE_DIST            % Records the average distance between all vehicles
    end
    
    methods (Abstract)
        % Abstract methods are methods that have to be implemented by any classes derived from the
        % class.
        triangulate(this)
        propogate(this)
    end
    
    % PUBLIC METHODS
    methods
        
        function init(this, args)
            %INIT Initializer for the simulator class.
            
            % Detect invalid number of arguments.
            n = size(args, 2);
            if n < 1 || n > 2
                error("Invalid number of arguments provided");
            end
            
            % Set file
            [~, filename, fileext] = fileparts(args{1});
            this.file = strcat(cd, '\data\', filename, fileext);
            
            % Create logging directorys
            this.LOG_PATH = strcat(cd, "\logs\",  filename);
            this.TIME_PATH = strcat(this.LOG_PATH, "\time.xls");
            this.EVENT_PATH = strcat(this.LOG_PATH, "\event.xls");
            [~, ~, ~] = mkdir(this.LOG_PATH);
            
            % Read simulation data from input file.
            this.simData = readJson(this.file);

            % Ensure correct type of map is being used
            if this.simData.type ~= this.type
                error("Invalid map type being used.")
            end
            
            % Setup random number generator
            rng(this.seed, 'combRecursive');
            
            % Initialize Vehicles
            this.initVehicles();
            
            % Set figures / axes
            this.plotMode = 0;
            if n == 2
                this.plotMode = args{2};
            end
            
            % Initialize distances
            this.distances = NaN(this.nVehicles, this.nVehicles);
            
            % Set params
            this.t = 0;
            this.speedup = 1;
            
            % Plot region
            this.initPlot();
        end
        
        function initVehicles(this)
            %INITVEHICLES Randomly initializes vehicles along the entry edge of the region. Does not
            %initialize the heading of the vehicles, however. The initialized heading is determined
            %by the triangulation method in the derived method.
            
            % Create array of spawn times
            t0 = 0:(1/this.fSpawn):this.tEnd;
            
            % Determine number of vehicles to be created.
            n = length(t0);
            
            % Direction of entry edge.
            v1 = this.entryEdge(1, :);
            v2 = this.entryEdge(2, :);
            
            % Direction of entry edge.
            d = v2 - v1;
            
            % Create vehicles array.
            this.vehicles = Vehicle.empty(0, n);
            for i = 1:n
                pt = v1 + d * rand;
                this.vehicles(i) = Vehicle(pt(1), pt(2), 0, this.velocity, t0(i));
            end
        end
        
        function initPlot(this)
            %INITPLOT Plots both bounding paths for the region along with edges joining the start
            %and end vertices of the paths.
            
            if this.hasAxis
                
                % Initialize plot map.
                fig = figure(1);
                this.mapAxis = axes(fig);

                % Setup axis
                cla(this.mapAxis);
                this.mapAxis.DataAspectRatio = [1, 1, 1];
                hold(this.mapAxis , 'on');

                % Plot the paths
                this.path1.plot(this.mapAxis, 'b');
                this.path2.plot(this.mapAxis, 'b');

                % Plot the entry and exit lines.
                plot(this.mapAxis, this.entryEdge(:, 1), this.entryEdge(:, 2), 'g', 'LineWidth', 1.5)
                plot(this.mapAxis, this.exitEdge(:, 1), this.exitEdge(:, 2), 'r', 'LineWidth', 1.5)

                % Plot the vertices along the paths
                scatter(this.mapAxis, this.path1.x, this.path1.y, 'r');
                scatter(this.mapAxis, this.path2.x, this.path2.y, 'r');

                % Label Axes
                xlabel(this.mapAxis, "x");
                ylabel(this.mapAxis, "y");
                title(this.mapAxis, "Map Region")
                
                % Set data axis
                if this.plotMode == 2
                    fig = figure(2);
                    this.dataAxis = axes(fig);
                end
                
            end
        end
        
        function plotTriangles(this)
            %PLOTTRIANGLES Plots the triangles on the map plot.
            
            if this.hasAxis
                for i = 1:size(this.triangles, 2)
                    % Plot triangle
                    tri = this.triangles(i);
                    tri.plot(this.mapAxis, 'g');

                    % Get centroid
                    v = tri.centroid;

                    % Get length 
                    len = (1/6) * tri.dirLength;

                    % Plot arrows
                    arrows(this.mapAxis, v(1), v(2), len, 90 - atan2(tri.dir(2), tri.dir(1)) * (180 / pi))
                end
            end
        end

        function pause(this)
            % PAUSE Pauses the simulation for a specified time.
            if this.hasAxis
                pause(this.dT / this.speedup);
            end
        end
        
        function plotVehicles(this)
            %PLOTVEHICLES Plots the currently active vehicles in the map.
            % Get position of active vehicles.
            
            if this.hasAxis 
                % Get locations
                i = this.activeVehicles;
                x = [this.vehicles(i).x];
                y = [this.vehicles(i).y];

                % Plot data
                hold(this.mapAxis, 'on');
                delete(this.handle)
                this.handle = scatter(this.mapAxis, x, y, 'r', '*');
            end
        end
        
        
        function terminateVehicle(this, i)
            %TERMINATEVEHICLE Terminates a vehicle.
            this.vehicles(i).terminate(this.t); % set vehicle flags
            this.distances(i, :) = NaN;
            this.distances(:, i) = NaN;
        end
        
        function updateDistances(this)
            %UPDATEDISTANCES Updates the distance matrix based on the current distance between all
            %vehicles.

            % Find indices of vehicles that are active
            indices = this.activeVehicles;
            n = size(indices, 2);
            
            % Create list
            iList = 1;
            list = NaN(n*n, 2);
            for i = 1:n
                ii = indices(i);
                for j = 1:n
                    jj = indices(j);
                    % Keep upper triangular
                    if ii <= jj 
                        continue;
                    end
                    list(iList, :) = [ii, jj];
                    iList = iList + 1;
                end
            end
            list(any(isnan(list), 2), :) = [];
            
            % Get dists
            if ~isempty(list)
                
                % Get locations
                src = [[this.vehicles(list(:, 1)).x]; [this.vehicles(list(:, 1)).y]]';
                dst = [[this.vehicles(list(:, 2)).x]; [this.vehicles(list(:, 2)).y]]';

                % Calculate dist
                dists = src - dst;
                dists = sqrt(dists(:, 1).^2 + dists(:, 2).^2);

                % Assign all items in parallel
                idx1 = sub2ind(size(this.distances), list(:,1), list(:,2));
                idx2 = sub2ind(size(this.distances), list(:,2), list(:,1)); 
                this.distances(idx1) = dists;
                this.distances(idx2) = dists;
            end
        end
        
        % Appends current data to the time logger.
        function TIMELOG(this)
            this.TIME = [this.TIME; this.t];
            this.NUM_ACTIVE_VEHICLES = [this.NUM_ACTIVE_VEHICLES; this.nActiveVehicles];
            this.AVERAGE_CLOSEST_DIST = [this.AVERAGE_CLOSEST_DIST; this.avgClosestDist];
            this.AVERAGE_DIST = [this.AVERAGE_DIST; this.avgDist];
        end
        
        % Writes data in logging parameters to the log files.
        function DUMP(this)
            TIME_DATA = [{'Time','NUM_ACTIVE_VEHICLES','AVERAGE_CLOSEST_DIST','AVERAGE_DIST'};...
                num2cell(this.TIME), num2cell(this.NUM_ACTIVE_VEHICLES), num2cell(this.AVERAGE_CLOSEST_DIST), num2cell(this.AVERAGE_DIST)];
            xlswrite(this.TIME_PATH, TIME_DATA)
        end
        
    end
    
    % GETTERS
    methods 
        
        function val = get.hasAxis(this)
            val = (this.plotMode > 0);
        end
        
        function val = get.path1(this)
            val = this.simData.paths(1);
        end
        
        function val = get.path2(this)
            val = this.simData.paths(2);
        end
        
        function val = get.dT(this)
            val = this.simData.properties.deltaT;
        end
        
        function val = get.fSpawn(this)
            val = this.simData.properties.spawnFreq;
        end
        
        function val = get.tEnd(this)
            val = (this.nVehicles - 1)/this.fSpawn;
        end 
        
        function val = get.seed(this)
            val = this.simData.properties.seed;
        end
        
        function val = get.velocity(this)
            val = this.simData.properties.velocity;
        end
        
        function val = get.entryEdge(this)
            val = [this.path1.coords(1, :); this.path2.coords(1, :)];
        end
        
        function val = get.exitEdge(this)
            val = [this.path1.coords(end, :); this.path2.coords(end, :)];
        end
        
        function val = get.nVehicles(this)
            val = this.simData.properties.nVehicles;
        end
        
        function val = get.nTriangles(this)
            val = size(this.triangles, 2);
        end
                
        function val = get.activeVehicles(this)
            val = find([this.vehicles.active] == 1);
        end
        
        function val = get.nActiveVehicles(this)
            val = size(this.activeVehicles, 2);
        end
        
        function val = get.avgClosestDist(this)
            val = mean(min(this.distances), 'omitnan');
        end
        
        function val = get.avgDist(this)
            val = mean(this.distances, 'all', 'omitnan');
        end
        
        function val = get.finished(this)
            val = (this.nActiveVehicles == 0);
        end
        
    end
end

