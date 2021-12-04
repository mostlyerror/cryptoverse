require 'httparty'
require 'amazing_print'
require 'time'

class KuCoin
  def self.get_symbols_list(opts = {})
    url = "https://api.kucoin.com/api/v1/symbols"
    HTTParty.send(:get, url, opts).yield_self do |response|
      response
    end
  end

  def self.lending_market_data(opts = {}, currency: "USDT", term: 7)
    url = "https://api.kucoin.com/api/v1/margin/market?currency=#{currency}&term=#{term}"
    HTTParty.send(:get, url, opts).yield_self do |response|
      response
    end
  end

  def self.margin_trade_data(opts = {}, currency: "USDT")
    url = "https://api.kucoin.com/api/v1/margin/trade/last?currency=#{currency}"
    HTTParty.send(:get, url, opts).yield_self do |response|
      JSON.parse(response.body).dig('data')
    end
  end
end

# get all the coins supported by kucoin for lending
# @symbols = KuCoin.get_symbols_list
# ap @symbols
# # understand the market APY on KuCoin for 7, 14, 28 terms for all currencies
#
# Read coinlist from newest coinlist file
latest = Dir
  .glob("data/coins/*.coinlist")
  .sort_by {|x| File.mtime(x) }
  .last
puts latest

File.open("data/market/#{Time.now.utc.iso8601}", "w") do |file|
  File.readlines(latest)
    .each do |symbol|
      @trades = KuCoin.margin_trade_data(currency: symbol)
      @by_terms = @trades.group_by {|t| t['term'] }

      # # for each term, calculate average interest rate & annualized APY
      # # 14=>
      # #   [{"tradeId"=>"61a6747a4215100001124d80",
      # #     "currency"=>"USDT",
      # #     "size"=>"29",
      # #     "dailyIntRate"=>"0.00042",
      # #     "term"=>14,
      # #     "timestamp"=>1638298746635793364}]}
      # # [7, 14, 28]
      @market_stats = @by_terms.map do |term, trades|
        average_daily_int_rate = trades.map {|t| t['dailyIntRate'].to_f }.sum / trades.size
        average_annualized_int_rate = average_daily_int_rate * 365 * 100
        stats = {
          num_trades: trades.size,
          average_daily_int_rate: average_daily_int_rate,
          average_annualized_int_rate: average_annualized_int_rate
        }
        Hash[term, stats]
      end
      data = Hash[symbol, @market_stats]
      file.puts(data.to_json)
      puts "#{symbol}: #{@market_stats.to_json}"
    end
end
