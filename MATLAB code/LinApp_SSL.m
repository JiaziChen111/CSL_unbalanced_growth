function [X, Y, E] = LinApp_SSL(X0,Z,XYbar,NN,PP,QQ,UU,...
                                logX,EE,Eps,Phi,funcname,param,Y0,RR,SS,VV)

% Version 1.1, written by Kerk Phillips, October 2016
%  
% Generates a history of X & Y variables by linearizing the policy function
% about the steady state as in Uhlig's toolkit.
%
% This function takes the following inputs:
%  X0    - 1-by-nx vector of X(1) starting values values
%  Z     - nobs-by-nz matrix of Z values
%  XYbar - 1-by-(nx+ny) vector of X and Y steady state values
%  PP    - nx-by-nx  matrix of X(t-1) on X(t) coefficients
%  QQ    - nx-by-nz  matrix of Z(t) on X(t) coefficients
%  UU    - nx-by-1 vector of X(t) constants
%  logX  - is an indicator that determines if the X & Y variables are
%          log-linearized (true) or simply linearized (false).  Z variables
%          are always simply linearized.
%  EE    - is an indicator that determines if the Euler errors are
%          calculated or not, default is 0 or do not calculate.
%  Eps   - nz-by-ne matrix of discrete values for the support of epsilon
%          shocks nect period (used for calculating Euler errors)
%  Phi   - nz-by-ne matrix of probabilities corresponding to the elements
%          of Eps
%  Y0    - 1-by-ny vector of Y(1) starting values values.
%  RR    - ny-by-nx  matrix of X(t-1) on Y(t) coefficients
%  SS    - ny-by-nz  matrix of Z(t) on Y(t) coefficients
%  VV    - ny-by-1 vector of Y(t) constants
%
% This function outputs the following:
%  X     - nobs-by-nx matrix containing the value of the endogenous
%          state variables for next period
%  Y     - nobs-by-ny matix vector containing the value of the endogenous
%          non-state variables for next period
%  E     - nobs-by-(nx+ny) matix vector containing the value of the Euler
%          errors each period
%
% Copyright: K. Phillips.  Feel free to copy, modify and use at your own 
% risk.  However, you are not allowed to sell this software or otherwise 
% impinge on its free distribution.

% Use log-linearized X & Y if no value is specified for logX
if (~exist('logX', 'var'))
    logX = true;
end
% Do not calculate Euler errors unless EE is set to 1
if (~exist('logX', 'var'))
    EE = false;
end
% set Y0, RR, SS, and VV to empty matrices if not passed.
if (~exist('Y0', 'var'))
    Y0 = [];
end
if (~exist('RR', 'var'))
    RR = [];
end
if (~exist('SS', 'var'))
    SS = [];
end
if (~exist('VV', 'var'))
    VV = [];
end
% set EE to false if not passed.
if (~exist('EE', 'var'))
    EE = false;
end

% get values for nx, ny, nz and nobs
[nobs,nz] = size(Z);
[~,nx] = size(X0);
[~,nxy] = size(XYbar);
ny = nxy - nx;

% get Xbar and Ybar
Xbar = XYbar(:,1:nx);
Ybar = XYbar(:,nx+1:nx+ny);

% Generate a history of X's and Y's
Xtil = zeros(nobs,nx);
Ytil = zeros(nobs,ny);
E = zeros(nobs,nx+ny);


% set starting values
X(1,:) = X0;
if ny>0
    Y(1,:) = Y0;
end
if logX
    Xtil(1,:) = log(X(1,:)./(Xbar));
    if ny>0
        Ytil(1,:) = log(Y(1,:)./Ybar);
    end
else
    Xtil(1,:) = X(1,:) - Xbar;
    if ny>0
        Ytil(1,:) = Y(1,:) - Ybar;
    end
end

% set values for future shocks in Euler equations
[~,ne] = size(Eps);

% Generate time series
for t=1:nobs-1
    % Since LinApp_Sim uses column vectors and inputs, transpose
    if ny>0
        [Xtemp, Ytemp] = ...
            LinApp_Sim(Xtil(t,:)',Z(t+1,:)',PP,QQ,UU,RR,SS,VV);
        Ytil(t+1,:) = Ytemp';
    else
        [Xtemp, ~] = ...
            LinApp_Sim(Xtil(t,:)',Z(t+1,:)',PP,QQ,UU);
    end
    Xtil(t+1,:) = Xtemp';
end

% Convert to levels
if logX
    X = repmat(Xbar,nobs,1).*exp(Xtil); 
    if ny> 0
        Y = repmat(Ybar,nobs,1).*exp(Ytil);
    else
        Y = [];
    end
else
    X = repmat(Xbar,nobs,1)+Xtil;
    if ny>0
        Y = repmat(Ybar,nobs,1)+Ytil;
    else
        Y = [];
    end
end

if EE==1
    % Calculate Euler Errors
    % Sum over observations
    for t=1:nobs-1
        % Recall Eps is value of epsilon and phi is the probability
        % Sum over potential shocks
        for e=1:ne
            % get conditional value of Zp
            Zp = NN*Z(t+1,:) + Eps(e,:);
            % generate conditional value of Xp and Yp
            Xdev = zeros(1,nx);
            Zdev = zeros(1,nz);
            % Since LinApp_Sim uses column vectors and inputs, transpose
            if ny>0
                [Xtil, Ytil] = LinApp_Sim(Xdev',Zdev',PP,QQ,UU,RR,SS,VV);
                Ytil = Ytil';
            else
                [Xtil, ~] = LinApp_Sim(Xdev',Zdev',PP,QQ,UU);
            end
            Xtil = Xtil';
            % Convert to levels
            if logX
                Xp = X(t+1,:).*exp(Xtil); 
                if ny> 0
                    Yp = Y(t+1,:).*exp(Ytil);
                else
                    Yp = [];
                end
            else
                Xp = X(t+1,:) + Xtil;
                if ny>0
                    Yp = Y(t+1,:) + Ytil;
                else
                    Y = [];
                end
            end
            % observed history
            theta2 = [Xp X(t+1,:) X(t,:) Zp Z(t+1)]';
            % Weight errors by probability and sum
            E(t,:) = E(t,:) + funcname(theta2,param)' * Phi(e);
        end
    end
end

end