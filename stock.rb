require 'json'
require 'sinatra'
require 'luis'
require 'stock_quote'
require 'bot_framework'

BotFramework.configure do |connector|
  connector.app_id = ENV['MICROSOFT_APP_ID']
  connector.app_secret = ENV['MICROSOFT_APP_SECRET']
end

Luis.configure do |config|
  config.id = ENV['STOCK_LUIS_ID']
  config.subscription_key = ENV['STOCK_LUIS_KEY']
  #config.is_preview_mod = true
end

post '/api/messages' do
  request.body.rewind # in case someone already read it
  input = JSON.parse request.body.read
  Thread.new {
  activity = BotFramework::Activity.new.build_from_hash input
  luis_result = Luis.query(activity.text)
  if luis_result.intents.count > 0
    case luis_result.intents[0].intent
    when 'StockPrice'
      stock = luis_result.entities[0].entity
      stock_value = StockQuote::Stock.quote(stock).ask
      result = " Current stock value of #{stock} is #{stock_value}"
      data = BotFramework::BotData.new(data: {last_stock: stock},e_tag: '*')
      BotFramework::BotState.new('').set_conversation_data('channel_id'=>activity.channel_id,
                                                           'conversation_id'=>activity.conversation.id,
                                                          'bot_data'=> data)
    when 'RepeatLastStock'
      data = BotFramework::BotState.new('').get_conversation_data('channel_id'=>activity.channel_id,
                                                           'conversation_id'=>activity.conversation.id)
      last_stock = data["data"]["last_stock"]
      if last_stock
        stock_value = StockQuote::Stock.quote(last_stock).ask
        result = " Current stock value of #{last_stock} is #{stock_value}"
      else
        result = "No previous value available"
      end
    when 'None'
      result = "Sorry , I don't undersatnd"
    end
  else
   result = "Sorry, I don't understand" 
  end
  activity.reply(result)
  }
end

post '/' do

end
