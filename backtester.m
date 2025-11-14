% ---
% Title: Simple MATLAB Backtester for a Combined Strategy
% Author: Gemini
% Date: 14-Nov-2025
%
% Description:
% This script provides a basic vector-based backtesting framework in MATLAB.
% It is designed to test a trading strategy that combines signals from:
% 1. Simple Moving Average (SMA) Crossover
% 2. Relative Strength Index (RSI)
% 3. A placeholder for a pattern-detection model (like your YOLOv8 model)
%
% This script uses built-in MATLAB data for demonstration purposes.
%
% Disclaimer: FOR EDUCATIONAL PURPOSES ONLY. NOT FINANCIAL ADVICE.
% ---

%% 1. Setup Environment
clear;         % Clear workspace
clc;           % Clear command window
close all;     % Close all figures

%% 2. Load and Prepare Data
% We will use a built-in dataset (Dow Jones Industrial) to make this
% script runnable for anyone.
% You can replace this section with your own data loader (e.g., readtable).

try
    % Load sample 'Data_GlobalIdx.mat' which contains 'dates' and 'ind'
    load('Data_GlobalIdx.mat');
    
    % Convert date numbers to datetime objects
    priceDates = datetime(dates, 'ConvertFrom', 'datenum');
    
    % We'll use the 'ind' series (DJI) as our closing prices
    % The data has 5 columns: [Open, High, Low, Close, Volume]
    % We will use the 4th column (Close) for our simple backtest.
    % Note: Your candle plotter for YOLO will need O,H,L,C data.
    prices = ind(:, 4);
    
    % Clean data: Remove any NaN rows from prices and corresponding dates
    nanRows = isnan(prices);
    prices = prices(~nanRows);
    priceDates = priceDates(~nanRows);
    
    fprintf('Loaded and prepared %d data points.\n', length(prices));
catch
    warning('Could not load sample data. Generating synthetic data.');
    prices = 100 + cumsum(randn(1000, 1) * 0.5) + sin((1:1000)'/50) * 5;
    priceDates = datetime('2020-01-01') + caldays(0:999);
end

%% 3. Define Strategy Parameters
% --- Indicator Parameters ---
strat.smaFastPeriod = 50;        % Fast SMA window
strat.smaSlowPeriod = 200;       % Slow SMA window
strat.rsiPeriod     = 14;        % RSI lookback period
strat.rsiOverbought = 70;        % RSI overbought threshold
strat.rsiOversold   = 30;        % RSI oversold threshold

% --- YOLO Model Parameters (Placeholder) ---
% You would define parameters for your chart generation here
strat.yoloChartWindow = 100;     % e.g., use 100 bars to generate the chart
strat.yoloConfidence  = 0.80;    % e.g., minimum confidence to trust a pattern

%% 4. Calculate Technical Indicators
% Note: Requires Financial Toolbox for movavg and rsindex
fprintf('Calculating technical indicators...\n');
try
    % Calculate Fast and Slow SMAs
    smaFast = movavg(prices, 'simple', strat.smaFastPeriod);
    smaSlow = movavg(prices, 'simple', strat.smaSlowPeriod);
    
    % Calculate RSI
    rsi = rsindex(prices, strat.rsiPeriod);
catch
    error('Financial Toolbox not found. Cannot calculate movavg or rsindex.');
end

%% 5. Generate Trading Signals

% --- Initialize signal vectors ---
numPoints = length(prices);
smaBuySignal    = zeros(numPoints, 1);
smaSellSignal   = zeros(numPoints, 1);
rsiBuySignal    = zeros(numPoints, 1);
rsiSellSignal   = zeros(numPoints, 1);
patternBuySignal  = zeros(numPoints, 1); % <--- YOLOv8 Placeholder
patternSellSignal = zeros(numPoints, 1); % <--- YOLOv8 Placeholder

% --- SMA Crossover Signals ---
% Vectorized calculation for crossovers
% 'lag' is used to check the previous state
sma_cross_up = (smaFast > smaSlow) & (lag(smaFast, 1) <= lag(smaSlow, 1));
sma_cross_down = (smaFast < smaSlow) & (lag(smaFast, 1) >= lag(smaSlow, 1));

smaBuySignal(sma_cross_up) = 1;   % Golden Cross
smaSellSignal(sma_cross_down) = 1; % Death Cross

% --- RSI Signals ---
% Vectorized calculation for threshold crosses
rsi_cross_up = (rsi < strat.rsiOversold) & (lag(rsi, 1) >= strat.rsiOversold);
rsi_cross_down = (rsi > strat.rsiOverbought) & (lag(rsi, 1) <= strat.rsiOverbought);

rsiBuySignal(rsi_cross_up) = 1;   % Entering oversold (buy signal)
rsiSellSignal(rsi_cross_down) = 1; % Entering overbought (sell signal)


% --- [CRITICAL] YOLOv8 Pattern Detection (Placeholder) ---
fprintf('Simulating pattern detection (placeholder)...\n');
% This is where you would integrate your Deep Learning model.
% The logic would be complex and CANNOT be fully vectorized easily,
% as it involves image generation and processing.
% You would likely run this inside your main backtesting loop (see Sec 6).

% --- Workflow for YOLO Integration ---
%
% 1. Load your ONNX model (do this once at the start of the script)
%    % REQUIRES DEEP LEARNING TOOLBOX
%    % net = importNetworkFromONNX('stockmarket-pattern-detection-yolov8.onnx');
%
% 2. In the backtesting loop (Section 6), for each day 'i':
%
%    a. Check if you have enough data:
%       % if i < strat.yoloChartWindow; continue; end
%
%    b. Get the data for the chart:
%       % windowData = ind(i - strat.yoloChartWindow + 1 : i, :); % O,H,L,C data
%
%    c. Generate the chart image (this is the trickiest part)
%       % You must create a figure and save it or grab its frame.
%       % f = figure('Visible', 'off', 'Position', [10 10 640 640]);
%       % candle(windowData(:,4), windowData(:,3), windowData(:,1), windowData(:,2));
%       % % You must remove axes, labels, etc., to match training data
%       % axis off;
%       % frame = getframe(f);
%       % img = frame.cdata;
%       % close(f);
%
%    d. Pre-process the image
%       % imgResized = imresize(img, [640 640]); % Match YOLO input
%       % imgProcessed = ... (normalize, etc.)
%
%    e. Run detection
%       % [bbox, score, label] = detect(net, imgProcessed);
%
%    f. Parse results and set signals
%       % for j = 1:length(label)
%       %    if label(j) == "bullish_pattern" && score(j) >= strat.yoloConfidence
%       %       patternBuySignal(i) = 1;
%       %    elseif label(j) == "bearish_pattern" && score(j) >= strat.yoloConfidence
%       %       patternSellSignal(i) = 1;
%       %    end
%       % end
%
% --- End of Workflow ---

% For this script, we'll just leave the pattern signals as zeros.
% You can manually add some '1's here to test the combined logic:
% e.g., patternBuySignal(150) = 1;
% e.g., patternSellSignal(300) = 1;


% --- Combine Signals into Final Strategy Logic ---
% This is your "secret sauce". How do you combine the signals?
% Example Logic:
% - BUY if (SMA is bullish OR RSI is oversold OR a bullish pattern appears)
% - SELL if (SMA is bearish OR RSI is overbought OR a bearish pattern appears)

finalBuySignal  = smaBuySignal | rsiBuySignal | patternBuySignal;
finalSellSignal = smaSellSignal | rsiSellSignal | patternSellSignal;

% Ensure we don't buy and sell on the same bar
finalBuySignal(finalSellSignal == 1) = 0;

%% 6. Run the Backtest (Event Loop)
fprintf('Running backtest...\n');

position = 0; % 0 = flat, 1 = long
equity = zeros(numPoints, 1);
initialCapital = 10000;
equity(1) = initialCapital;
numTrades = 0;

% We must start from 2, as 'lag' calculations make day 1 unusable
for i = 2:numPoints
    
    % Carry over equity from previous day
    equity(i) = equity(i-1);
    
    % --- This is where you would put the NON-VECTORIZED YOLO logic ---
    % (See Section 5 for the detailed workflow)
    
    % --- Check for Exit (Sell) Signal ---
    if position == 1 % We are currently in a long position
        if finalSellSignal(i) == 1
            % Sell! (Go flat)
            position = 0;
            numTrades = numTrades + 1;
            % Calculate profit/loss and update equity
            % This simple model assumes we trade at the close.
            % A more realistic model would use position(i-1) to
            % calculate returns, which is done in the performance section.
            % For this loop, we just track state.
        end
        
    % --- Check for Entry (Buy) Signal ---
    elseif position == 0 % We are currently flat
        if finalBuySignal(i) == 1
            % Buy! (Go long)
            position = 1;
            numTrades = numTrades + 1;
        end
    end
    
    % Store the position for this day (for performance calculation)
    % 1 = was long, 0 = was flat
    positions(i) = position;
    
end

% Shift positions by 1 day:
% Our position at the end of day 'i' (positions(i)) determines the
% return we get for day 'i+1'.
positions_lagged = lag(positions, 1);
positions_lagged(1) = 0; % Start flat


%% 7. Calculate Performance
fprintf('Calculating performance metrics...\n');

% Calculate daily returns of the asset (Buy & Hold)
dailyReturns_BH = (prices - lag(prices, 1)) ./ lag(prices, 1);
dailyReturns_BH(1) = 0;

% Calculate strategy returns (only earn returns when in position)
strategyReturns = positions_lagged .* dailyReturns_BH;
strategyReturns(isnan(strategyReturns)) = 0;

% Calculate cumulative returns
cumReturns_BH = cumprod(1 + dailyReturns_BH) - 1;
cumReturns_Strategy = cumprod(1 + strategyReturns) - 1;

% Final Metrics
totalReturn_BH = cumReturns_BH(end) * 100;
totalReturn_Strategy = cumReturns_Strategy(end) * 100;
numDays = length(prices);

fprintf('\n--- BACKTEST RESULTS (%.f days) ---\n', numDays);
fprintf('Total Trades: %d\n', numTrades);
fprintf('Buy & Hold Return: %.2f%%\n', totalReturn_BH);
fprintf('Strategy Return:   %.2f%%\n', totalReturn_Strategy);
fprintf('--------------------------------------\n');


%% 8. Plot Results
fprintf('Plotting results...\n');

figure('Name', 'Backtest Results', 'NumberTitle', 'off');

% --- Plot 1: Equity Curve ---
subplot(2, 1, 1);
h1 = plot(priceDates, (1 + cumReturns_Strategy) * initialCapital, 'b', 'LineWidth', 2);
hold on;
h2 = plot(priceDates, (1 + cumReturns_BH) * initialCapital, 'r--', 'LineWidth', 1.5);
title(sprintf('Strategy vs. Buy & Hold (%.f trades)', numTrades));
legend([h1, h2], 'Strategy Equity', 'Buy & Hold Equity', 'Location', 'northwest');
ylabel('Equity ($)');
xlabel('Date');
grid on;

% --- Plot 2: Price and Signals ---
subplot(2, 1, 2);
plot(priceDates, prices, 'k', 'LineWidth', 1);
title('Price, SMAs, and Trade Signals');
hold on;
plot(priceDates, smaFast, 'c-', 'LineWidth', 1);
plot(priceDates, smaSlow, 'm-', 'LineWidth', 1.5);

% Find buy and sell points
buyPoints = (finalBuySignal == 1) & (positions_lagged == 0);
sellPoints = (finalSellSignal == 1) & (positions_lagged == 1);

% Plot buy/sell markers
plot(priceDates(buyPoints), prices(buyPoints), 'g^', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
plot(priceDates(sellPoints), prices(sellPoints), 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

legend('Price', 'SMA Fast', 'SMA Slow', 'Buy Signal', 'Sell Signal', 'Location', 'northwest');
ylabel('Price ($)');
xlabel('Date');
grid on;

% --- (Optional) Plot 3: RSI ---
% figure('Name', 'RSI');
% plot(priceDates, rsi, 'g');
% hold on;
% line([priceDates(1), priceDates(end)], [strat.rsiOverbought, strat.rsiOverbought], 'Color', 'r');
% line([priceDates(1), priceDates(end)], [strat.rsiOversold, strat.rsiOversold], 'Color', 'b');
% title('RSI');
% grid on;

fprintf('Done.\n');