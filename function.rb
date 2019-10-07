# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
  if event['path'] == '/token'
    if event['httpMethod'].upcase == 'POST'
      generate_token(request: event)
    else
      response(status: 405)
    end
  elsif event['path'] == '/'
    if event['httpMethod'].upcase == 'GET'
      get_token_data(request: event)
    else
      response(status: 405)
    end
  else
    response(body: event, status: 404)
  end
end

def generate_token(request: event)
  body = {}
  begin
    body = JSON.parse(request['body'])
  rescue
    return response(status: 422)
  end
  PP.pp request
  # return response(status: 422) unless request['body'].class == Hash
  return response(status: 415) unless request['headers']['Content-Type'] == 'application/json'

  payload = {
      data: body,
      exp: Time.now.to_i + 1,
      nbf: Time.now.to_i
  }
  token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  response(body:
  {
    token: token
  }, status: 201)
end

def get_token_data(request: event)
  response(status: 200)
end

def response(body: nil, status: 200)
  {
    body: body ? body.to_json + "\n" : '',
    statusCode: status
  }
end

if $PROGRAM_NAME == __FILE__
  # If you run this file directly via `ruby function.rb` the following code
  # will execute. You can use the code below to help you test your functions
  # without needing to deploy first.
  ENV['JWT_SECRET'] = 'NOTASECRET'

  # Call /token
  PP.pp main(context: {}, event: {
               'body' => '{"name": "bboe"}',
               'headers' => { 'Content-Type' => 'application/json' },
               'httpMethod' => 'POST',
               'path' => '/token'
             })

  # Generate a token
  payload = {
    data: { user_id: 128 },
    exp: Time.now.to_i + 1,
    nbf: Time.now.to_i
  }
  token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  # Call /
  PP.pp main(context: {}, event: {
               'headers' => { 'Authorization' => "Bearer #{token}",
                              'Content-Type' => 'application/json' },
               'httpMethod' => 'GET',
               'path' => '/'
             })
end
