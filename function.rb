# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'

def lowercaseKeys(hash)
  result = {}
  hash.to_hash.each_pair do |k, v|
    result.merge!(k.downcase => v)
  end

  result
end

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
  request = lowercaseKeys event

  # return print request
  if request['path'] == '/token'
    if request['httpmethod'] == 'POST'
      generate_token(request: request)
    else
      response(status: 405)
    end
  elsif request['path'] == '/'
    if request['httpmethod'] == 'GET'
      get_token_data(request: request)
    else
      response(status: 405)
    end
  else
    response(body: request, status: 404)
  end
end

def generate_token(request: event)
  body = {}
  begin
    body = JSON.parse(request['body'])
  rescue StandardError
    return response(status: 422)
  end
  # return response(status: 422) unless request['body'].class == Hash
  unless lowercaseKeys(request['headers'])['content-type'] == 'application/json'
    return response(status: 415)
  end

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
  unless lowercaseKeys(request['headers'])['authorization'].start_with?('Bearer ')
    return response(status: 403)
  end

  begin
    token = lowercaseKeys(request['headers'])['authorization'][7..-1]
    decoded_token = JWT.decode token, ENV['JWT_SECRET'], true, algorithm: 'HS256'
    return response(status: 401) unless decoded_token[0].key?('data')

    response(body: decoded_token[0]['data'], status: 200)
  rescue JWT::ImmatureSignature
    # Handle invalid token, e.g. logout user or deny access
    response(status: 401)
  end
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
