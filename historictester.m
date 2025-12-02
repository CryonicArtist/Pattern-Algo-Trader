%% 1. Big Data Setup: Smart Import & Filter
clear; clc; close all;

% --- USER SETTINGS ---
csvFileName = 'marketdata.csv'; % Ensure this matches your file name
cacheFile   = 'marketdata.mat'; % Name for the fast loading file

% Define the specific period you want to test (e.g., 2008 Crash, or 2020)
testStartDate = datetime(2008, 01, 01); 
testEndDate   = datetime(2021, 12, 31); 

initialCapital = 10000;
% ---------------------

% Step A: Smart Loader (Checks for cache first)
if exist(cacheFile, 'file')
    disp('Loading data from fast cache (.mat)...');
    load(cacheFile, 'rawTable');
else
    disp('Reading large CSV file (this takes time on first run)...');
    opts = detectImportOptions(csvFileName);
    opts.VariableNamingRule = 'preserve'; % Keep column names as 'date', 'close', etc.
    
    % optimize for memory
    opts = setvartype(opts, {'open','high','low','close'}, 'single'); 
    
    rawTable = readtable(csvFileName, opts);
    
    % CONVERSION: Matches the format in your screenshot (yyyy-MM-dd HH:mm:ss)
    disp('Converting timestamps...');
    rawTable.DateTime = datetime(rawTable.date, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    
    disp('Saving .mat cache for future runs...');
    save(cacheFile, 'rawTable');
end

% Step B: Filter for the selected Date Range
mask = (rawTable.DateTime >= testStartDate) & (rawTable.DateTime <= testEndDate);
data = rawTable(mask, :);

if isempty(data)
    error('No data found in the selected Date Range! Check your Start/End dates.');
end

% Extract arrays for the Algo
timeVector = data.DateTime;
closeP = double(data.close); % Convert to double for math precision
disp(['Backtesting ' num2str(length(closeP)) ' bars from ' char(testStartDate) ' to ' char(testEndDate)]);

%% 2. High-Speed Indicator Calculation (Vectorized)
% Using matrix operations instead of loops for speed on 1M+ rows
rsiPeriod = 14; stochPeriod = 14; 
smoothK = 3; smoothD = 3;

% Standard RSI
rawRSI = rsindex(closeP, rsiPeriod);

% Fast StochRSI Calculation
% Window [13 0] means: Look back 13 bars + current bar = 14 bars total
lowestRSI  = movmin(rawRSI, [stochPeriod-1, 0]);
highestRSI = movmax(rawRSI, [stochPeriod-1, 0]);

% Calculate Raw StochRSI
% Handle division by zero if flat
rangeRSI = highestRSI - lowestRSI;
rangeRSI(rangeRSI == 0) = 1; % Prevent NaN
stochRsiRaw = (rawRSI - lowestRSI) ./ rangeRSI;
stochRsiRaw = stochRsiRaw * 100;

% Smoothing (%K and %D) using Moving Average
K = movmean(stochRsiRaw, [smoothK-1, 0]);
D = movmean(K, [smoothD-1, 0]);

%% 3. Strategy Execution Loop
cash = initialCapital;
shares = 0;
inPosition = false; 
tradeCount = 0;
equityCurve = zeros(size(closeP));

% Pre-allocate signal arrays for speed (showing sparse markers)
buySignal = nan(size(closeP));
sellSignal = nan(size(closeP));

% Buy & Hold Reference
bnhShares = floor(initialCapital / closeP(1));
bnhCash = initialCapital - (bnhShares * closeP(1));

% Fast Loop
for t = 2:length(closeP)
    currK = K(t); prevK = K(t-1);
    currD = D(t); prevD = D(t-1);
    
    % Track Equity
    if inPosition
        currentVal = cash + (shares * closeP(t));
    else
        currentVal = cash;
    end
    equityCurve(t) = currentVal;

    % Skip warm-up periods
    if isnan(currK) || isnan(prevK), continue; end

    % --- BUY LOGIC ---
    if (prevK < prevD) && (currK > currD) && (currK < 60) && ~inPosition
        shares = floor(cash / closeP(t));
        cash = cash - (shares * closeP(t));
        inPosition = true;
        tradeCount = tradeCount + 1;
        % Only record signal marker if not too cluttered
        if mod(tradeCount, 1) == 0, buySignal(t) = closeP(t); end
    end

    % --- SELL LOGIC ---
    if (prevK > prevD) && (currK < currD) && inPosition
        cash = cash + (shares * closeP(t));
        shares = 0;
        inPosition = false;
        sellSignal(t) = closeP(t);
    end
end

% Force Liquidation at End
if inPosition
    cash = cash + (shares * closeP(end));
    shares = 0;
    equityCurve(end) = cash;
end

% Final Stats
finalStrategy = equityCurve(end);
finalBnH = bnhCash + (bnhShares * closeP(end));
stratProfit = finalStrategy - initialCapital;
bnhProfit = finalBnH - initialCapital;

if stratProfit > bnhProfit
    algoColor = 'green'; bnhColor = 'white'; winnerStr = 'ALGO WINS';
else
    algoColor = 'white'; bnhColor = 'green'; winnerStr = 'BUY & HOLD WINS';
end

%% 4. Visualization (Equity Curve)
fig = figure('Position', [100, 50, 1100, 800], 'Color', [0.15 0.15 0.15]);

% --- Plot 1: Account Growth (The most important chart for long term) ---
ax1 = subplot(2,1,1);
set(ax1, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9]);
hold on;
plot(timeVector, equityCurve, 'g-', 'LineWidth', 1); % Algo
plot(timeVector, (bnhShares .* closeP) + bnhCash, 'Color', [0.6 0.6 0.6], 'LineStyle', '--'); % Buy&Hold
title(['Account Growth (2008-2021)'], 'Color', 'w');
ylabel('Value ($)'); 
legend('Algo Equity', 'Buy & Hold', 'TextColor', 'w', 'Color', [0.2 0.2 0.2], 'Location', 'northwest');
grid on;

% --- Plot 2: Price Action ---
ax2 = subplot(2,1,2);
set(ax2, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9]);
hold on;
plot(timeVector, closeP, 'w-', 'LineWidth', 0.5);
% Only plot signals if we are looking at < 6 months of data to avoid clutter
if length(closeP) < 100000 
    plot(timeVector, buySignal, '^', 'Color', '#00FF00', 'MarkerSize', 6, 'MarkerFaceColor', 'g');
    plot(timeVector, sellSignal, 'v', 'Color', '#FF0000', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
end
title('Price Action', 'Color', 'w');
ylabel('Price'); grid on;

linkaxes([ax1, ax2], 'x');

% --- SCOREBOARD ---
scoreText = {
    '\bf\fontsize{12}   LONG-TERM RESULTS   ';
    '-------------------------';
    sprintf('Range: %s to %s', char(testStartDate, 'yyyy-MM-dd'), char(testEndDate, 'yyyy-MM-dd'));
    ' ';
    '\bf --- YOUR ALGO ---';
    sprintf('Final Total   : \color{%s}$%.2f', algoColor, finalStrategy);
    sprintf('Profit/Loss   : $%+.2f', stratProfit);
    sprintf('Total Trades  : %d', tradeCount);
    ' ';
    '\bf --- BUY & HOLD ---';
    sprintf('Final Total   : \color{%s}$%.2f', bnhColor, finalBnH);
    sprintf('Profit/Loss   : $%+.2f', bnhProfit);
    '-------------------------';
    ['\bf RESULT: ' winnerStr]
};

dim = [0.14 0.50 0.25 0.35];
annotation('textbox', dim, 'String', scoreText, ...
    'FitBoxToText', 'off', 'BackgroundColor', [0.2 0.2 0.2], ...
    'EdgeColor', 'w', 'Color', 'w', 'FontName', 'Consolas', 'FontSize', 9, 'Interpreter', 'tex');