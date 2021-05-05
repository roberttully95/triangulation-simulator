beep off
addpath(genpath("src"))

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pathJsonFile = 'curvedPath.json';
pathVelFile = 'curvedPath.xls';
triangulation = Triangulation.Closest;
plotMap = 1;
simSpeedup = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This runs the simulation without velocity change.
%{
    % Path Simulator
    pathsim = Simulator(pathJsonFile, triangulation, plotMap);
    pathsim.speedup = simSpeedup;
    while ~pathsim.finished
        pathsim.propogate();
    end
    pathsim.writeLogFiles();
%}

% NOTE: WHEN RUNNING WITH VELOCITY CHANGE, THE VELOCY AND NUMBER OF
% VEHICLES IN THE CONFIG FILES IS IGNORED, AND ONLY THE VELOCITY 
% TABLE data IS USED.

% Run simulator with velocity change.
pathsim = VelChangeSimulator(pathJsonFile, pathVelFile, triangulation, plotMap);
pathsim.speedup = simSpeedup;
while ~pathsim.finished
    pathsim.propogate();
end
pathsim.writeLogFiles();

% Send email
%sendEmail('files/login.ini', 'Simulation Finished', 'The simulation has finished succsefully');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%