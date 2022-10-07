# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'
require 'bundler/setup' #to do remove

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
  if event['path'] == '/' || event['path'] == '/token'
    if event['path'] == '/' && event['httpMethod'] == 'GET'
      get(body: event)
    elsif event['path'] == '/token' && event['httpMethod'] == 'POST'
      post(body: event)
    else
      response(body: {"error": "wrong http method"}, status: 405)
    end
  else
    response(body: {"error": "resource not found"}, status: 404)
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
  auth_wording = body['headers'].keys.grep(/#{"authorization"}/i)
  auth = body['headers'][auth_wording[0]]
  if auth == nil
    response(body: {"error": "please specify auth token"}, status: 403)
  else
    begin
      encoded_token = auth.split(" ")[1]
      token = JWT.decode encoded_token, ENV['JWT_SECRET'], true, { algorithm: 'HS256' }
      response(body: token[0]["data"], status: 200)
    rescue JWT::ImmatureSignature => ise
      response(body: {"error": ise}, status: 401)
    rescue JWT::ExpiredSignature => exe
      response(body: {"error": exe}, status: 401)
    rescue JWT::DecodeError => e
      response(body: {"error": "decode error"}, status: 403)
    end
  end
end

def post(body: nil)
  ct_wording = body['headers'].keys.grep(/#{"content-type"}/i)
  ct_type = body['headers'][ct_wording[0]]
  if ct_type != 'application/json'
    response(body: {'error': 'response type is not application/json'}, status: 415)
  elsif !valid_json?(body['body'])
    response(body: {'error': 'not a valid json'}, status: 422)
  else
    uncoded_token = {
      data: JSON.parse(body["body"]),
      exp: Time.now.to_i + 5,
      nbf: Time.now.to_i + 2
    }
    encoded_token = JWT.encode uncoded_token, ENV['JWT_SECRET'], 'HS256'
    response(body: {"token": encoded_token}, status: 201)
  end
end

def valid_json?(json)
  if (json == nil)
    return false
  end
  JSON.parse(json)
  true
rescue JSON::ParserError => e
  false
end


if $PROGRAM_NAME == __FILE__
  # If you run this file directly via `ruby function.rb` the following code
  # will execute. You can use the code below to help you test your functions
  # without needing to deploy first.
  ENV['JWT_SECRET'] = 'NOTASECRET'
  my_token = main(context: {}, event: {
    'body' => '{"name": "bboe"}',
    'headers' => { 'coNtEnt-tYpe' => 'application/json' },
    'httpMethod' => 'POST',
    'path' => '/token'
  })
  # Call /token
  puts "my_token"
  PP.pp my_token
  encoded_tokena = JSON.parse(my_token[:body])["token"]
  puts "encoded_tokena"
  PP.pp encoded_tokena
  # PP.pp main(context: {}, event: {
  #   'body' => `1`,
  #   'headers' => { 'content-type' => 'application/json' },
  #   'httpMethod' => 'POST',
  #   'path' => '/token'
  # })
  # token_decode_arr = JWT.decode encoded_tokena,  'ASECRET', true, { algorithm: 'HS256' }
  # PP.pp decoded_tokena
  # # Generate a token
  payload = {
    data: { user_id: 128 },
    exp: Time.now.to_i + 1,
    nbf: Time.now.to_i
  }
  token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  puts "token1"
  puts token
  # Call /
  PP.pp main(context: {}, event: {
               'headers' => { 'auTHOrIzation' => "Bearer #{encoded_tokena}",
                              'Content-Type' => 'application/json' },
               'httpMethod' => 'GET',
               'path' => '/'
             })
end
