%% MATLAB "Sniper" Algo Trader (RSI + Limit Orders)
% Strategy: "Catch the Bottom"
%   1. Calculate "Fair Value" (20-Day EMA)
%   2. Place a LIMIT ORDER at the Lower Bollinger Band.
%   3. If RSI is < 40 (Oversold), we execute the trade aggressively.
%   4. Compare performance against a passive "Buy & Hold" strategy.

clear; clc; close all;

%% --- 1. DATA GENERATION (Simulating High/Low/Close) ---
% We simulate 'High' and 'Low' prices to allow for "Wick" trading
days = 252 * 3;      % 3 Years
start_price = 150;   
mu = 0.0005;         % Drift (General upward trend)
sigma = 0.02;        % Volatility (Market noise)

dates = (1:days)';
close_price = zeros(days, 1);
high_price = zeros(days, 1);
low_price = zeros(days, 1);
close_price(1) = start_price;

rng('shuffle'); % Random seed
for t = 2:days
    % Generate Close Price
    shock = randn;
    close_price(t) = close_price(t-1) * exp((mu - 0.5 * sigma^2) + sigma * shock);
    
    % Simulate High and Low (Wicks)
    % High is typically 0.5% to 3% above close/open
    daily_vol = rand * 0.03; 
    high_price(t) = close_price(t) * (1 + daily_vol);
    low_price(t) = close_price(t) * (1 - daily_vol);
end

%% --- 2. INDICATORS (RSI + Bollinger) ---
window = 20;
std_devs = 2.0; 

% A. Exponential Moving Average (Faster than SMA)
ema = zeros(days, 1);
k = 2 / (window + 1);
ema(1) = close_price(1);
for t = 2:days
    ema(t) = close_price(t) * k + ema(t-1) * (1 - k);
end

% B. Bollinger Bands
upper_band = zeros(days, 1);
lower_band = zeros(days, 1);
for t = window:days
    slice = close_price(t-window+1 : t);
    stdev = std(slice);
    upper_band(t) = ema(t) + (std_devs * stdev);
    lower_band(t) = ema(t) - (std_devs * stdev);
end

% C. RSI (Relative Strength Index)
rsi_period = 14;
rsi = zeros(days, 1);
change = [0; diff(close_price)];
avg_gain = 0; avg_loss = 0;

% Initial RSI Calculation
for t = 2:rsi_period+1
    gain = max(0, change(t));
    loss = abs(min(0, change(t)));
    avg_gain = avg_gain + gain;
    avg_loss = avg_loss + loss;
end
avg_gain = avg_gain / rsi_period;
avg_loss = avg_loss / rsi_period;

for t = rsi_period+2:days
    gain = max(0, change(t));
    loss = abs(min(0, change(t)));
    
    avg_gain = (avg_gain * (rsi_period-1) + gain) / rsi_period;
    avg_loss = (avg_loss * (rsi_period-1) + loss) / rsi_period;
    
    rs = avg_gain / avg_loss;
    rsi(t) = 100 - (100 / (1 + rs));
end

%% --- 3. TRADING LOGIC (THE SNIPER) ---
initial_capital = 10000;
capital = initial_capital;
position = 0; 
portfolio_value = zeros(days, 1);
buy_signals = nan(days, 1); 
sell_signals = nan(days, 1); 
trade_log = [];

% Warmup Period: We cannot trade before indicators exist
for t = 1:window
    portfolio_value(t) = initial_capital;
end

for t = window+1 : days
    current_close = close_price(t);
    
    % Target Buy Price = The Lower Band (The "Discount" Price)
    limit_buy_order = lower_band(t);
    
    % --- BUY LOGIC (Limit Order) ---
    if position == 0
        % Check 1: Did the price wick down to our limit order?
        % Check 2: Is RSI Oversold (< 40) to confirm the dip is real?
        if (low_price(t) <= limit_buy_order) && (rsi(t) < 40)
            
            % EXECUTION: We buy at the LIMIT PRICE, not the Close.
            execution_price = limit_buy_order; 
            
            shares = floor(capital / execution_price);
            if shares > 0
                capital = capital - (shares * execution_price);
                position = shares;
                buy_signals(t) = execution_price;
                trade_log = [trade_log; t, 1, execution_price]; 
            end
        end
        
    % --- SELL LOGIC (Take Profit) ---
    elseif position > 0
        % Sell if we hit the upper band OR if RSI gets too hot (> 75)
        if (high_price(t) >= upper_band(t)) || (rsi(t) > 75)
            % We sell at the Close or the Band, whichever is achievable
            execution_price = max(upper_band(t), current_close);
            
            capital = capital + (position * execution_price);
            position = 0;
            sell_signals(t) = execution_price;
            trade_log = [trade_log; t, -1, execution_price]; 
        end
    end
    
    % Mark to Market (Daily Account Value)
    portfolio_value(t) = capital + (position * current_close);
end

%% --- 4. BENCHMARK: BUY & HOLD ---
% We start Buy & Hold on Day (window+1) to be fair (same start time as Algo)
start_index = window + 1;
bh_shares = floor(initial_capital / close_price(start_index));
bh_cash_remainder = initial_capital - (bh_shares * close_price(start_index));

% Calculate BH Value over time
bh_curve = zeros(days, 1);
bh_curve(1:window) = initial_capital; % Flat during warmup
bh_curve(window+1:end) = bh_cash_remainder + (bh_shares .* close_price(window+1:end));

%% --- 5. REPORTING & METRICS ---
algo_return = ((portfolio_value(end) - initial_capital) / initial_capital) * 100;
bh_return = ((bh_curve(end) - initial_capital) / initial_capital) * 100;

fprintf('\n--- PERFORMANCE REPORT ---\n');
fprintf('Initial Capital:  $%.2f\n', initial_capital);
fprintf('Final Algo Value: $%.2f\n', portfolio_value(end));
fprintf('Final B&H Value:  $%.2f\n', bh_curve(end));
fprintf('--------------------------\n');
fprintf('Algo Return:      %.2f%%\n', algo_return);
fprintf('Buy&Hold Return:  %.2f%%\n', bh_return);
fprintf('Total Trades:     %d\n', size(trade_log,1));

if algo_return > bh_return
    fprintf('RESULT: Algo BEAT the market by %.2f%%\n', algo_return - bh_return);
else
    fprintf('RESULT: Algo LOST to the market by %.2f%%\n', bh_return - algo_return);
end

%% --- 6. VISUALIZATION ---
figure('Name', 'Sniper Strategy vs Buy & Hold', 'Color', 'k', 'Position', [100, 100, 1200, 800]);

% Subplot 1: Price Actions & Executions
subplot(3,1,1:2);
plot(dates, upper_band, 'r-', 'LineWidth', 0.5); hold on;
plot(dates, lower_band, 'g-', 'LineWidth', 0.5);
plot(dates, close_price, 'w-', 'LineWidth', 1);
plot(dates, buy_signals, 'g^', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
plot(dates, sell_signals, 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
title('Sniper Strategy (Limit Order Entries)', 'Color', 'w');
legend('Sell Zone', 'Buy Zone', 'Price', 'Sniper Buy', 'Sell Signal', 'TextColor', 'w', 'Color', 'k');
set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
grid on;

% Subplot 2: Equity Curve Comparison
subplot(3,1,3);
area(dates, portfolio_value, 'FaceColor', [0 0.5 0], 'FaceAlpha', 0.4, 'EdgeColor', 'g'); hold on;
plot(dates, bh_curve, 'w--', 'LineWidth', 1.5); % White dashed line for B&H
title('Account Growth: Algo vs. Buy & Hold', 'Color', 'w');
legend('Algo Equity', 'Buy & Hold Equity', 'Location', 'best', 'TextColor', 'w', 'Color', 'k');
ylabel('Value ($)', 'Color', 'w');
xlabel('Trading Days', 'Color', 'w');
set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
grid on;