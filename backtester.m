%% MATLAB Realistic P/E Algo Trader
% Strategy: Buy when Price-to-Earnings (P/E) is historically low.
%           Sell when P/E is historically high.
% NO "God Mode" - The bot trades based on public Earnings data only.

clear; clc; close all;

%% --- 1. PARAMETERS & DATA GENERATION ---
days = 252 * 5;      % 5 Years
start_earn = 5.00;   % Starting Earnings Per Share (EPS)
avg_pe = 20;         % The "Fair" P/E Ratio
volatility = 0.02;   % Volatility of the company earnings

% Pre-allocate
dates = (1:days)';
earnings = zeros(days, 1);
market_price = zeros(days, 1);
pe_ratios = zeros(days, 1);

% Initialize
earnings(1) = start_earn;
% Market starts at "Fair Value"
market_price(1) = start_earn * avg_pe; 
pe_ratios(1) = avg_pe;

% Generate Data
rng('shuffle'); 
current_pe_sentiment = avg_pe; % Starts at 20

for t = 2:days
    % 1. Generate Earnings (Random Walk with slight upward drift)
    % Earnings grow slowly (0.05% per day) but have noise
    earnings(t) = earnings(t-1) * (1 + 0.0005 + randn * 0.01); 
    
    % 2. Generate Market Sentiment (P/E Ratio)
    % Sentiment swings like a pendulum around the average of 20
    sentiment_shock = randn * 0.5; 
    % Mean reversion strength (pulls P/E back to 20)
    pull_back = (avg_pe - current_pe_sentiment) * 0.05; 
    current_pe_sentiment = current_pe_sentiment + pull_back + sentiment_shock;
    
    % 3. Calculate Price
    % Price = Earnings * P/E Ratio
    market_price(t) = earnings(t) * current_pe_sentiment;
    pe_ratios(t) = current_pe_sentiment;
end

%% --- 2. STRATEGY (REALISTIC) ---
initial_capital = 10000;
capital = initial_capital;
position = 0; 
commission = 5; 

portfolio_value = zeros(days, 1);
buy_signals = nan(days, 1);
sell_signals = nan(days, 1);
trade_log = [];

% Estimated Fair Value (This is the Bot's "Prediction")
% The bot assumes the stock is always worth 20x Earnings.
estimated_fair_value = earnings * avg_pe;

for t = 1:days
    current_price = market_price(t);
    my_fair_value = estimated_fair_value(t); % Earnings * 20
    
    % Logic: 
    % If Price is 15% below Fair Value (P/E < 17) -> BUY
    % If Price is 15% above Fair Value (P/E > 23) -> SELL
    
    if position == 0
        % Buy Deep Value
        if current_price < (my_fair_value * 0.85) 
            shares = floor((capital - commission) / current_price);
            if shares > 0
                cost = shares * current_price + commission;
                capital = capital - cost;
                position = shares;
                buy_signals(t) = current_price;
                trade_log = [trade_log; t, 1, current_price, pe_ratios(t)];
            end
        end
    else
        % Sell Overhyped
        if current_price > (my_fair_value * 1.15)
            revenue = position * current_price - commission;
            capital = capital + revenue;
            position = 0;
            sell_signals(t) = current_price;
            trade_log = [trade_log; t, -1, current_price, pe_ratios(t)];
        end
    end
    
    portfolio_value(t) = capital + (position * current_price);
end

%% --- 3. BENCHMARK ---
bh_shares = floor((initial_capital - commission) / market_price(1));
bh_value = (initial_capital - (bh_shares*market_price(1)+commission)) + (bh_shares .* market_price);

%% --- 4. REPORTING ---
% A. Fundamental Data Sheet
DataSheet = table(dates, round(earnings,2), round(pe_ratios,1), ...
    round(estimated_fair_value,2), round(market_price,2), ...
    'VariableNames', {'Day', 'EPS_Earnings', 'PE_Ratio', 'Calc_Fair_Value', 'MarketPrice'});

fprintf('--- FUNDAMENTAL DATA SHEET (First 10 Days) ---\n');
disp(head(DataSheet, 10));

% B. Metrics
algo_return = ((portfolio_value(end) - initial_capital) / initial_capital) * 100;
bh_return = ((bh_value(end) - initial_capital) / initial_capital) * 100;

fprintf('--- PERFORMANCE ---\n');
fprintf('Algo Return:     %.2f%%\n', algo_return);
fprintf('Buy&Hold Return: %.2f%%\n', bh_return);
fprintf('Total Trades:    %d\n', size(trade_log,1));

% C. Dark Mode Visualization
figure('Name', 'P/E Value Strategy', 'Color', 'k', 'Position', [100, 100, 1000, 600]);

% Subplot 1: Price vs Fair Value
subplot(2,1,1);
plot(dates, market_price, 'w-', 'LineWidth', 1); hold on;
plot(dates, estimated_fair_value, 'c--', 'LineWidth', 1.5);
plot(dates, buy_signals, 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
plot(dates, sell_signals, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
title('Price vs. Estimated Fair Value (Earnings * 20)', 'Color', 'w');
legend('Market Price', 'Fair Value (EPS * 20)', 'Buy', 'Sell', 'TextColor', 'w');
ylabel('Price ($)', 'Color', 'w');
grid on;
set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');

% Subplot 2: The P/E Ratio (The Valuation Metric)
subplot(2,1,2);
yline(20, 'w--', 'Fair P/E (20)'); hold on;
plot(dates, pe_ratios, 'm-', 'LineWidth', 1);
yline(17, 'g-', 'Buy Zone (<17)');
yline(23, 'r-', 'Sell Zone (>23)');
title('Valuation Metric: P/E Ratio', 'Color', 'w');
ylabel('P/E Ratio', 'Color', 'w');
xlabel('Day', 'Color', 'w');
grid on;
set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');