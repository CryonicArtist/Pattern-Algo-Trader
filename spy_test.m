%% 1. Setup: Import Real Market Data
clear; clc; close all;

% --- USER CONFIGURATION ---
fileName = '1marketdata.csv'; 
% IMPORTANT: Change this date to one that exists in your CSV!
targetDate = datetime(2023, 10, 25); 
initialCapital = 10000;
commission = 0; 
% --------------------------

% Try to load and parse the CSV
try
    opts = detectImportOptions(fileName);
    opts.VariableNamingRule = 'preserve'; 
    rawTable = readtable(fileName, opts);
    
    % Attempt to construct a DateTime column
    % (Adjust 'Date' and 'Time' if your CSV headers are different)
    if ismember('Date', rawTable.Properties.VariableNames) && ismember('Time', rawTable.Properties.VariableNames)
        rawTable.DateTime = datetime(rawTable.Date) + timeofday(datetime(rawTable.Time, 'InputFormat', 'HH:mm:ss'));
    else
        % Fallback: Assume first column is datetime
        rawTable.DateTime = datetime(rawTable{:,1});
    end

    % FILTER: Keep only the target date
    dayMask = (year(rawTable.DateTime) == year(targetDate)) & ...
              (month(rawTable.DateTime) == month(targetDate)) & ...
              (day(rawTable.DateTime) == day(targetDate));
    
    dayData = rawTable(dayMask, :);
    
    if isempty(dayData)
        error('Data loaded, but NO rows matched your targetDate.');
    end
    
    % Assign Data to Vectors
    timeVector = dayData.DateTime;
    closeP = dayData.Close; % Ensure your CSV has a 'Close' column
    
    disp(['Successfully loaded ' num2str(length(closeP)) ' bars for ' char(targetDate)]);

catch ME
    % Fallback if file missing or parse error
    warning(['CSV Import Failed: ' ME.message]);
    warning('Generating DUMMY DATA so you can still see the chart.');
    
    % Generate dummy data
    timeVector = (datetime('now'):minutes(1):datetime('now')+hours(6.5))';
    closeP = 150 + cumsum(randn(length(timeVector),1)*0.2);
end

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

for t = 2:length(closeP)
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

% Determine Winner for Display formatting
if stratProfit > bnhProfit
    algoColor = 'green'; bnhColor = 'white';
    winnerStr = 'ALGO WINS';
else
    algoColor = 'white'; bnhColor = 'green';
    winnerStr = 'BUY & HOLD WINS';
end

%% 4. Night Mode Visualization
fig = figure('Position', [100, 50, 1100, 800], 'Color', [0.15 0.15 0.15]);

% --- Plot 1: Price & Signals ---
ax1 = subplot(2,1,1);
set(ax1, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9]);
hold on;
plot(timeVector, closeP, 'w-', 'LineWidth', 1.5);
plot(timeVector, buySignal, '^', 'Color', '#00FF00', 'MarkerFaceColor', '#00FF00', 'MarkerSize', 8);
plot(timeVector, sellSignal, 'v', 'Color', '#FF0000', 'MarkerFaceColor', '#FF0000', 'MarkerSize', 8);
title(['Real Data Analysis: ' char(targetDate)], 'Color', 'w');
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

linkaxes([ax1, ax2], 'x');
xlim(ax1, [timeVector(1) timeVector(end)]);

% --- ENHANCED SCOREBOARD ---
scoreText = {
    '\bf\fontsize{12}   FINAL RESULTS   ';
    '-------------------------';
    sprintf('Start Balance : $%.2f', initialCapital);
    ' ';
    '\bf --- YOUR ALGO ---';
    sprintf('Final Total   : \color{%s}$%.2f', algoColor, finalStrategy);
    sprintf('Profit/Loss   : $%+.2f', stratProfit);
    sprintf('Trades Made   : %d', tradeCount);
    ' ';
    '\bf --- BUY & HOLD ---';
    sprintf('Final Total   : \color{%s}$%.2f', bnhColor, finalBnH);
    sprintf('Profit/Loss   : $%+.2f', bnhProfit);
    '-------------------------';
    ['\bf RESULT: ' winnerStr]
};

% Draw the Text Box
dim = [0.14 0.55 0.25 0.32]; % [x y width height]
annotation('textbox', dim, 'String', scoreText, ...
    'FitBoxToText', 'off', ...
    'BackgroundColor', [0.2 0.2 0.2], ...
    'EdgeColor', 'w', ...
    'Color', 'w', ...
    'FontName', 'Consolas', ... 
    'FontSize', 10, ...
    'Interpreter', 'tex');