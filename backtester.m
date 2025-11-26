%% 1. Setup: Create 1 Day of 5-Minute Data
clear; clc; close all;

% Define Time: 9:30 AM to 4:00 PM in 5-minute increments
startTime = datetime(2023,1,1,9,30,0);
endTime = datetime(2023,1,1,16,0,0);
timeVector = (startTime : minutes(5) : endTime)';
numBars = length(timeVector);

% Generate Synthetic Data (Random Walk)
rng(42); % Set seed so data matches previous example
volatility = 0.2; 
startPrice = 150;

% Simulate Price
change = randn(numBars, 1) * volatility;
closeP = startPrice + cumsum(change);
highP  = closeP + abs(randn(numBars, 1) * 0.1); 
lowP   = closeP - abs(randn(numBars, 1) * 0.1); 

%% 2. Calculate Indicators
period = 14; 

% RSI
rsiVec = rsindex(closeP, period);

% Stochastic %K
stochData = stochosc(highP, lowP, closeP, period, 3);
stochK = stochData(:,1);

%% 3. Run Strategy Logic
buySignal = nan(size(closeP));
sellSignal = nan(size(closeP));

for t = 2:numBars
    currK = stochK(t);      prevK = stochK(t-1);
    currRSI = rsiVec(t);    prevRSI = rsiVec(t-1);
    
    if isnan(currK) || isnan(currRSI), continue; end

    % BEARISH: Stoch crosses OVER RSI
    if (prevK < prevRSI) && (currK > currRSI)
        sellSignal(t) = closeP(t);
    end

    % BULLISH: Stoch crosses UNDER RSI
    if (prevK > prevRSI) && (currK < currRSI)
        buySignal(t) = closeP(t);
    end
end

%% 4. Night Mode Visualization
% Set Figure background to Dark Gray
fig = figure('Position', [100, 100, 1200, 800], 'Color', [0.15 0.15 0.15]);

% --- Top Plot: Price Action ---
ax1 = subplot(2,1,1);
set(ax1, 'Color', [0.1 0.1 0.1], ...       % Axis background (Black)
         'XColor', [0.9 0.9 0.9], ...      % X-axis Text (Off-White)
         'YColor', [0.9 0.9 0.9], ...      % Y-axis Text (Off-White)
         'GridColor', [1 1 1], ...         % Grid lines (White)
         'GridAlpha', 0.15);               % Grid transparency

hold on;
plot(timeVector, closeP, 'w-', 'LineWidth', 1.5); % Price is now White
plot(timeVector, buySignal, '^', 'Color', '#00FF00', 'MarkerFaceColor', '#00FF00', 'MarkerSize', 10); % Neon Green
plot(timeVector, sellSignal, 'v', 'Color', '#FF0000', 'MarkerFaceColor', '#FF0000', 'MarkerSize', 10); % Bright Red

title('Price Action (Night Mode)', 'Color', 'w');
ylabel('Price ($)');
legend('Price', 'Buy', 'Sell', 'TextColor', 'w', 'EdgeColor', 'w', 'Color', [0.2 0.2 0.2]);
grid on;

% --- Bottom Plot: Indicators ---
ax2 = subplot(2,1,2);
set(ax2, 'Color', [0.1 0.1 0.1], ...
         'XColor', [0.9 0.9 0.9], ...
         'YColor', [0.9 0.9 0.9], ...
         'GridColor', [1 1 1], ...
         'GridAlpha', 0.15);

hold on;
% Stochastic is Cyan (High contrast)
plot(timeVector, stochK, 'c-', 'LineWidth', 1.5); 
% RSI is Magenta (High contrast)
plot(timeVector, rsiVec, 'm-', 'LineWidth', 1.5); 

% Threshold lines (Light Gray)
yline(80, '--', 'Color', [0.7 0.7 0.7]);
yline(20, '--', 'Color', [0.7 0.7 0.7]);

title('Stochastic (Cyan) vs RSI (Magenta)', 'Color', 'w');
legend('Stochastic %K', 'RSI', 'TextColor', 'w', 'EdgeColor', 'w', 'Color', [0.2 0.2 0.2]);
grid on;