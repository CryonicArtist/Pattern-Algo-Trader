%% MATLAB RIM Value Trader (Fixed Volatility)
% Strategy: Fundamental Value Investing (Residual Income Model)
% Fix applied: Increased market volatility to trigger Buy/Sell signals.
% Design: Dark Mode with Area Charts.

clear; clc; close all;

%% --- 1. FUNDAMENTAL DATA GENERATION ---
days = 252 * 5;      % 5 Years
start_price = 50;    

% Fundamental Assumptions
cost_of_equity = 0.08;   % Discount Rate (r)
growth_rate = 0.03;      % Long Term Growth (g)
payout_ratio = 0.40;     % Dividends paid out
start_book_val = 40;     % Starting Assets per share

dates = (1:days)';
market_price = zeros(days, 1);
intrinsic_value = zeros(days, 1);

% Accounting Vectors
eps_vec = zeros(days, 1);       
book_val_vec = zeros(days, 1);  
div_vec = zeros(days, 1);       
roe_vec = zeros(days, 1);       

% Initialize
market_price(1) = start_price;
book_val_vec(1) = start_book_val;
current_eps = start_book_val * 0.12; % Start with 12% ROE
eps_vec(1) = current_eps;

% SENTIMENT TRACKER
% We start slightly optimistic so it has room to fall
current_sentiment = 1.0; 

rng('shuffle'); 

for t = 2:days
    % A. SIMULATE BUSINESS (Earnings & Book Value)
    shock = randn * 0.04; % Business Volatility
    current_eps = current_eps * (1 + 0.0002 + shock); 
    
    dividend = max(0, current_eps * payout_ratio);
    retained_earnings = current_eps - dividend;
    
    book_val_vec(t) = book_val_vec(t-1) + (retained_earnings / 252); 
    eps_vec(t) = current_eps;
    div_vec(t) = dividend;
    
    current_roe = current_eps / book_val_vec(t);
    roe_vec(t) = current_roe;
    
    % B. CALCULATE INTRINSIC VALUE (RIM FORMULA)
    residual_income_component = ((current_roe - cost_of_equity) * book_val_vec(t)) / (cost_of_equity - growth_rate);
    raw_value = book_val_vec(t) + residual_income_component;
    
    % Smooth the value line
    if t == 2
        intrinsic_value(t) = raw_value;
    else
        intrinsic_value(t) = (raw_value * 0.05) + (intrinsic_value(t-1) * 0.95);
    end
    % Fix 1: Bankruptcy Floor for Value
    intrinsic_value(t) = max(0.01, intrinsic_value(t)); 

    % C. GENERATE MARKET PRICE (The Volatility Fix)
    % Increase drift (0.03) so sentiment swings wider
    sentiment_drift = randn * 0.03; 
    
    % Decrease gravity (0.005) so price stays irrational longer
    gravity = (1.0 - current_sentiment) * 0.005; 
    
    current_sentiment = current_sentiment + sentiment_drift + gravity;
    
    % Clamp sentiment to realistic bubbles/crashes (0.6x to 2.0x value)
    current_sentiment = max(0.6, min(2.0, current_sentiment));
    
    market_price(t) = intrinsic_value(t) * current_sentiment;
    % Fix 2: Bankruptcy Floor for Price
    market_price(t) = max(0.01, market_price(t)); 
end
intrinsic_value(1) = intrinsic_value(2);

%% --- 2. TRADING LOGIC ---
initial_capital = 10000;
capital = initial_capital;
position = 0; 
portfolio_value = zeros(days, 1);
buy_signals = nan(days, 1); 
sell_signals = nan(days, 1); 
trade_log = [];

% Thresholds
margin_of_safety = 0.85;   % Buy when Price is < 85% of Value
overvalued_trigger = 1.15; % Sell when Price is > 115% of Value

for t = 1:days
    current_price = market_price(t);
    my_value = intrinsic_value(t);
    
    % BUY LOGIC
    if position == 0
        if current_price < (my_value * margin_of_safety)
            shares = floor(capital / current_price);
            if shares > 0
                capital = capital - (shares * current_price);
                position = shares;
                buy_signals(t) = current_price;
                trade_log = [trade_log; t, 1, current_price];
            end
        end
        
    % SELL LOGIC
    elseif position > 0
        if current_price > (my_value * overvalued_trigger)
            capital = capital + (position * current_price);
            position = 0;
            sell_signals(t) = current_price;
            trade_log = [trade_log; t, -1, current_price];
        end
    end
    
    portfolio_value(t) = capital + (position * current_price);
end

%% --- 3. BENCHMARK & ALPHA ---
bh_shares = floor(initial_capital / market_price(1));
bh_curve = (initial_capital - bh_shares*market_price(1)) + (bh_shares .* market_price);

algo_return = ((portfolio_value(end) - initial_capital) / initial_capital) * 100;
bh_return = ((bh_curve(end) - initial_capital) / initial_capital) * 100;
alpha = algo_return - bh_return;

%% --- 4. REPORTING ---
fprintf('\n--- RIM STRATEGY RESULTS ---\n');
fprintf('Initial Capital:  $%.2f\n', initial_capital);
fprintf('Algo Final:       $%.2f (%.2f%%)\n', portfolio_value(end), algo_return);
fprintf('Buy & Hold:       $%.2f (%.2f%%)\n', bh_curve(end), bh_return);
fprintf('Total Trades:     %d\n', size(trade_log,1));
fprintf('----------------------------\n');
if alpha > 0
    fprintf('RESULT: Algo BEAT Market by +%.2f%%\n', alpha);
else
    fprintf('RESULT: Algo LAGGED Market by %.2f%%\n', alpha);
end

%% --- 5. VISUALIZATION ---
figure('Name', 'RIM Strategy (Dark Mode)', 'Color', 'k', 'Position', [100, 100, 1200, 800]);

% Subplot 1: Fundamentals vs Price
subplot(3,1,1:2);
plot(dates, intrinsic_value, 'c-', 'LineWidth', 2); hold on;
plot(dates, book_val_vec, 'm--', 'LineWidth', 1.5); 
plot(dates, market_price, 'w-', 'LineWidth', 1);
plot(dates, buy_signals, 'g^', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
plot(dates, sell_signals, 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

title('RIM Strategy: Price vs Intrinsic Value', 'Color', 'w', 'FontSize', 14);
legend('Intrinsic Value (RIM)', 'Book Value (Floor)', 'Market Price', 'Buy Signal', 'Sell Signal', ...
       'TextColor', 'w', 'Color', 'k', 'Location', 'best');
set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
grid on;

% Subplot 2: Equity Curve (Area Chart)
subplot(3,1,3);
area(dates, portfolio_value, 'FaceColor', [0 0.5 0], 'FaceAlpha', 0.4, 'EdgeColor', 'g'); hold on;
plot(dates, bh_curve, 'w--', 'LineWidth', 1.5); 

if alpha > 0
    title_str = sprintf('Account Growth: Algo Winning by +%.2f%%', alpha);
else
    title_str = sprintf('Account Growth: Algo Losing by %.2f%%', alpha);
end

title(title_str, 'Color', 'w', 'FontSize', 12);
legend('Algo Equity', 'Buy & Hold', 'TextColor', 'w', 'Color', 'k', 'Location', 'northwest');
ylabel('Value ($)', 'Color', 'w');
xlabel('Trading Days', 'Color', 'w');
set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
grid on;