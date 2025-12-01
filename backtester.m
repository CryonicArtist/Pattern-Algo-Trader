%% 1. Setup: Random Market Data
clear; clc; close all;
rng('shuffle'); % Randomize every time

% Simulation Parameters
initialCapital = 10000;
commission = 0; 

% Define Time
startTime = datetime('today') + hours(9) + minutes(30);
endTime = startTime + hours(6.5);
timeVector = (startTime : minutes(5) : endTime)';
numBars = length(timeVector);

% Generate Price Data
volatility = 0.15 + (rand() * 0.35); 
dayTrend = (rand() - 0.5) * 0.25;    
startPrice = 100 + randi(100);       
change = (randn(numBars, 1) * volatility) + dayTrend;
closeP = startPrice + cumsum(change);

%% 2. Calculate StochRSI
rsiPeriod = 14; stochPeriod = 14; smoothK = 3; smoothD = 3;

rawRSI = rsindex(closeP, rsiPeriod);
stochRsiRaw = nan(size(rawRSI));

for i = (rsiPeriod + stochPeriod):length(rawRSI)
    rsiWindow = rawRSI(i-stochPeriod+1 : i);
    if max(rsiWindow) - min(rsiWindow) == 0, stochRsiRaw(i) = 0;
    else, stochRsiRaw(i) = (rawRSI(i) - min(rsiWindow)) / (max(rsiWindow) - min(rsiWindow)); end
end

stochRsiRaw = stochRsiRaw * 100;
K = nan(size(stochRsiRaw)); D = nan(size(K));
for i = smoothK:length(stochRsiRaw), K(i) = mean(stochRsiRaw(i-smoothK+1 : i)); end
for i = smoothD:length(K), D(i) = mean(K(i-smoothD+1 : i)); end

%% 3. Strategy Execution Loop
cash = initialCapital;
shares = 0;
inPosition = false; 
buySignal = nan(size(closeP));
sellSignal = nan(size(closeP));
tradeCount = 0;

% Buy & Hold Reference
bnhShares = floor(initialCapital / closeP(1));
bnhCash = initialCapital - (bnhShares * closeP(1));

for t = 2:numBars
    currK = K(t); prevK = K(t-1);
    currD = D(t); prevD = D(t-1);
    
    if isnan(currK) || isnan(currD) || isnan(prevK) || isnan(prevD), continue; end

    % BUY LOGIC: Cross Over + Below 60 + Cash Available
    if (prevK < prevD) && (currK > currD) && (currK < 60) && ~inPosition
        shares = floor(cash / closeP(t)); 
        cash = cash - (shares * closeP(t)) - commission;
        inPosition = true;
        buySignal(t) = closeP(t);
        tradeCount = tradeCount + 1;
    end

    % SELL LOGIC: Cross Under + Holding Shares
    if (prevK > prevD) && (currK < currD) && inPosition
        cash = cash + (shares * closeP(t)) - commission;
        shares = 0;
        inPosition = false;
        sellSignal(t) = closeP(t);
    end
end

% Force Liquidation at End of Day
if inPosition
    cash = cash + (shares * closeP(end));
    shares = 0;
    sellSignal(end) = closeP(end);
end

% Final Calculations
finalStrategy = cash;
finalBnH = bnhCash + (bnhShares * closeP(end));
stratProfit = finalStrategy - initialCapital;
bnhProfit = finalBnH - initialCapital;

% Determine Winner for Display
if stratProfit > bnhProfit
    winnerStr = 'ALGO WINS'; winColor = 'g';
else
    winnerStr = 'BUY & HOLD WINS'; winColor = 'r';
end

%% 4. Night Mode Visualization
fig = figure('Position', [100, 50, 1000, 800], 'Color', [0.15 0.15 0.15]);

% --- Plot 1: Price & Signals ---
ax1 = subplot(2,1,1);
set(ax1, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9]);
hold on;
plot(timeVector, closeP, 'w-', 'LineWidth', 1.5);
plot(timeVector, buySignal, '^', 'Color', '#00FF00', 'MarkerFaceColor', '#00FF00', 'MarkerSize', 8);
plot(timeVector, sellSignal, 'v', 'Color', '#FF0000', 'MarkerFaceColor', '#FF0000', 'MarkerSize', 8);
title(sprintf('Random Market Day (Trend: %.2f)', dayTrend), 'Color', 'w');
ylabel('Price'); grid on;

% --- Plot 2: Indicators ---
ax2 = subplot(2,1,2);
set(ax2, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9]);
hold on;
plot(timeVector, K, 'c-', 'LineWidth', 1.5); 
plot(timeVector, D, 'm-', 'LineWidth', 1.5); 
yline(60, '--', 'Buy Limit', 'Color', 'y', 'LabelHorizontalAlignment', 'left');
yline(20, '--', 'Color', [0.5 0.5 0.5]);
yline(80, '--', 'Color', [0.5 0.5 0.5]);
title('StochRSI', 'Color', 'w'); ylabel('0-100'); grid on;

% Link Axes
linkaxes([ax1, ax2], 'x');
xlim(ax1, [timeVector(1) timeVector(end)]);

% --- TEXT CHART SCOREBOARD ---
% Create the text box content
scoreText = {
    '\bf PERFORMANCE REPORT';
    '------------------------------';
    sprintf('Start Balance : $%.2f', initialCapital);
    '------------------------------';
    sprintf('Strategy End  : $%.2f', finalStrategy);
    sprintf('Strategy P/L  : \color{%s}$%+.2f', winColor, stratProfit);
    sprintf('Total Trades  : %d', tradeCount);
    '------------------------------';
    sprintf('\color{white}Buy & Hold End: $%.2f', finalBnH);
    sprintf('Buy & Hold P/L: $%+.2f', bnhProfit);
    '------------------------------';
    ['\bf RESULT: ' winnerStr]
};

% Draw the Text Box (Top Left of Figure)
dim = [0.15 0.60 0.25 0.25]; % [x y width height]
annotation('textbox', dim, 'String', scoreText, ...
    'FitBoxToText', 'on', ...
    'BackgroundColor', [0.2 0.2 0.2], ...
    'EdgeColor', 'w', ...
    'Color', 'w', ...
    'FontName', 'Consolas', ... % Monospace font for alignment
    'FontSize', 10, ...
    'Interpreter', 'tex');