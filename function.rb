# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'
require 'bundler/setup' #to do remove

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
  if event['path'] == '/' && event['httpMethod'] == 'GET'
    get(body: event)
  end
  #response(body: event, status: 200)
end

def response(body: nil, status: 200)
  {
    body: body ? body.to_json + "\n" : '',
    statusCode: status
  }
end

def get(body: nil)
  auth = body['headers']['Authorization']
  if auth == nil
    response(body: {'error': 'please specify auth token'}, status: 403)
  else
    encoded_token = auth[7..-1]
    token = JWT.decode encoded_token, ENV['JWT_SECRET'], 'HS256'
    if token[0]['exp'].to_i < Time.now.to_i
      response(body: {'error': 'token expired'}, status: 401)
    else
      if token[0]['nbf'].to_i > Time.now.to_i
        response(body: {'error': 'token not yet valid'}, status: 401)
      else
        response(body: token[0]['data'], status: 200)
      end
    end
  end
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
