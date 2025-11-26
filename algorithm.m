%% 1. Setup and Data Generation
clear; clc; close all;

% Create dummy price data (Random walk for demonstration)
T = 200; % Number of time periods
dates = datetime('today') - caldays(T-1:-1:0);
price = 100 + cumsum(randn(T, 1)); % Simulated Close Price
high = price + rand(T, 1);         % Simulated High
low = price - rand(T, 1);          % Simulated Low
closeP = price;

%% 2. Calculate Indicators
% Standard 14-period settings
period = 14;

% Calculate RSI
rsiVec = rsindex(closeP, period);

% Calculate Stochastic (%K line)
% stochosc returns [PercentK, PercentD]. We only need K for your rule.
stochData = stochosc(high, low, closeP, period, 3); 
stochK = stochData(:, 1); 

%% 3. The Algorithm Logic (Signal Detection)
% Initialize signal vectors with zeros
buySignals = nan(size(closeP));
sellSignals = nan(size(closeP));

% Loop through data starting from period+1 to avoid index errors
for t = 2:length(closeP)
    
    % Define Previous and Current values for cleaner code
    prevK = stochK(t-1);
    currK = stochK(t);
    prevRSI = rsiVec(t-1);
    currRSI = rsiVec(t);
    
    % Rule 1: Bullish (Stoch intercepts and goes UNDER RSI)
    % Logic: It was above yesterday, it is below today
    if (prevK > prevRSI) && (currK < currRSI)
        buySignals(t) = closeP(t); % Record the price at the buy signal
    end
    
    % Rule 2: Bearish (Stoch intercepts OVER RSI)
    % Logic: It was below yesterday, it is above today
    if (prevK < prevRSI) && (currK > currRSI)
        sellSignals(t) = closeP(t); % Record the price at the sell signal
    end
end

%% 4. Visualization
figure('Position', [100, 100, 1000, 600]);

% Subplot 1: Price and Signals
subplot(2,1,1);
plot(dates, closeP, 'k', 'LineWidth', 1.5); hold on;
plot(dates, buySignals, 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g'); % Green Up Arrow
plot(dates, sellSignals, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); % Red Down Arrow
title('Price Action with Algo Signals');
legend('Price', 'Buy Signal', 'Sell Signal');
grid on;

% Subplot 2: The Indicators
subplot(2,1,2);
plot(dates, stochK, 'b', 'LineWidth', 1); hold on;
plot(dates, rsiVec, 'r', 'LineWidth', 1);
yline(80, '--', 'Overbought');
yline(20, '--', 'Oversold');
title('Strategy Logic: Stochastic (Blue) vs RSI (Red)');
legend('Stochastic %K', 'RSI');
grid on;