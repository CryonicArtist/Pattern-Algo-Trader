%% 1. Setup: Generate 1 Random Day
clear; clc; close all;
rng('shuffle'); % New random scenario every time

% Simulation Params
initialCapital = 10000;
volatility = 0.15 + (rand() * 0.35); % Random Volatility
dayTrend = (rand() - 0.5) * 0.25;    % Random Trend

% Time: 9:30 AM to 4:00 PM
startTime = datetime('today') + hours(9) + minutes(30);
endTime = startTime + hours(6.5);
timeVector = (startTime : minutes(5) : endTime)';
numBars = length(timeVector);

% Generate Price
startPrice = 100 + randi(100); 
change = (randn(numBars, 1) * volatility) + dayTrend;
closeP = startPrice + cumsum(change);

%% 2. Calculate StochRSI
rsiPeriod = 14; stochPeriod = 14; smoothK = 3; smoothD = 3;

rawRSI = rsindex(closeP, rsiPeriod);
stochRsiRaw = nan(size(rawRSI));
for i = (rsiPeriod + stochPeriod):length(rawRSI)
    window = rawRSI(i-stochPeriod+1 : i);
    minR = min(window); maxR = max(window);
    if maxR - minR == 0, stochRsiRaw(i) = 0;
    else, stochRsiRaw(i) = (rawRSI(i) - minR) / (maxR - minR); end
end
stochRsiRaw = stochRsiRaw * 100;

K = nan(size(stochRsiRaw)); D = nan(size(K));
for i = smoothK:length(stochRsiRaw), K(i) = mean(stochRsiRaw(i-smoothK+1 : i)); end
for i = smoothD:length(K), D(i) = mean(K(i-smoothD+1 : i)); end

%% 3. Strategy Execution vs Buy & Hold
% --- ALGO TRADER ---
cash = initialCapital;
shares = 0;
inPosition = false; 
buySignal = nan(size(closeP));
sellSignal = nan(size(closeP));
tradeLog = {}; 

for t = 2:numBars
    currK = K(t); prevK = K(t-1);
    currD = D(t); prevD = D(t-1);
    
    if isnan(currK) || isnan(currD) || isnan(prevK) || isnan(prevD), continue; end

    % BUY RULE: Cross Over + K < 60 + Cash Available
    if (prevK < prevD) && (currK > currD) && (currK < 60) && ~inPosition
        shares = floor(cash / closeP(t));
        cash = cash - (shares * closeP(t));
        inPosition = true;
        buySignal(t) = closeP(t);
        tradeLog{end+1} = sprintf('BUY  @ %s : $%.2f', datestr(timeVector(t),'HH:MM'), closeP(t));
    end

    % SELL RULE: Cross Under + Holding Shares
    if (prevK > prevD) && (currK < currD) && inPosition
        cash = cash + (shares * closeP(t));
        shares = 0;
        inPosition = false;
        sellSignal(t) = closeP(t);
        tradeLog{end+1} = sprintf('SELL @ %s : $%.2f', datestr(timeVector(t),'HH:MM'), closeP(t));
    end
end

% Algo Force Close
if inPosition
    cash = cash + (shares * closeP(end));
    shares = 0;
    sellSignal(end) = closeP(end);
    tradeLog{end+1} = sprintf('CLOSE@ %s : $%.2f (EOD)', datestr(timeVector(end),'HH:MM'), closeP(end));
end
algoFinal = cash;
algoProfit = algoFinal - initialCapital;

% --- BUY & HOLD TRADER ---
bnhShares = floor(initialCapital / closeP(1));
bnhResid = initialCapital - (bnhShares * closeP(1));
bnhFinal = (bnhShares * closeP(end)) + bnhResid;
bnhProfit = bnhFinal - initialCapital;

%% 4. Visualization
fig = figure('Position', [100, 100, 1200, 800], 'Color', [0.15 0.15 0.15]);

% Top: Price Action
ax1 = subplot(2,2,[1 2]); 
set(ax1, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9]);
hold on;
plot(timeVector, closeP, 'w-', 'LineWidth', 1.5);
plot(timeVector, buySignal, '^', 'Color', '#00FF00', 'MarkerFaceColor', '#00FF00', 'MarkerSize', 10);
plot(timeVector, sellSignal, 'v', 'Color', '#FF0000', 'MarkerFaceColor', '#FF0000', 'MarkerSize', 10);
title(sprintf('Random Day (Trend: %.2f | Vol: %.2f)', dayTrend, volatility), 'Color', 'w');
ylabel('Price'); grid on;

% Bottom Left: Indicators
ax2 = subplot(2,2,3);
set(ax2, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9]);
hold on;
plot(timeVector, K, 'c-', 'LineWidth', 1.5); 
plot(timeVector, D, 'm-', 'LineWidth', 1.5); 
yline(60, '--', 'Buy Limit (<60)', 'Color', 'y', 'LabelHorizontalAlignment', 'left');
yline(20, '--', 'Color', [0.5 0.5 0.5]);
yline(80, '--', 'Color', [0.5 0.5 0.5]);
title('StochRSI', 'Color', 'w'); ylim([0 100]); grid on;
linkaxes([ax1, ax2], 'x'); xlim(ax1, [timeVector(1) timeVector(end)]);

% Bottom Right: Comparisons
ax3 = subplot(2,2,4);
set(ax3, 'Color', [0.2 0.2 0.2], 'XTick', [], 'YTick', [], 'Box', 'on');
title('Performance Report', 'Color', 'w');

% Construct the Text
if isempty(tradeLog), tradeLog = {'No trades triggered.'}; end

summaryText = tradeLog;
summaryText{end+1} = ' ';
summaryText{end+1} = '__________________________';
summaryText{end+1} = ' ';
summaryText{end+1} = sprintf('ALGO END : $%.2f', algoFinal);
summaryText{end+1} = sprintf('HOLD END : $%.2f', bnhFinal);
summaryText{end+1} = '__________________________';
summaryText{end+1} = ' ';

if algoProfit > bnhProfit
    diff = algoProfit - bnhProfit;
    summaryText{end+1} = 'WINNER: ALGO TRADER';
    summaryText{end+1} = sprintf('Beats Market By: +$%.2f', diff);
else
    diff = bnhProfit - algoProfit;
    summaryText{end+1} = 'WINNER: BUY & HOLD';
    summaryText{end+1} = sprintf('Beats Algo By: +$%.2f', diff);
end

text(0.1, 0.95, summaryText, 'Color', 'w', 'FontName', 'Consolas', 'FontSize', 10, ...
    'VerticalAlignment', 'top', 'Interpreter', 'none');