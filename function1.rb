require 'json'
require 'jwt'
require 'pp'

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html

  if event['path'] != "/" and event['path'] != "/token"
    return response(status: 404)
  end
  event["headers"] = event["headers"].transform_keys(&:downcase)
  if event["path"] == '/token'
    if event["httpMethod"] != "POST"
      response(status: 405)
    elsif event["httpMethod"] == "POST"
      if event["headers"]["content-type"] != "application/json"
        response(status: 415)
      elsif event["body"] == nil or event["body"] == ''
        response(status: 422)
      else
        begin
          parse_body = JSON.parse(event["body"])
          # Generate a token
          payload = {
            data: parse_body,
            exp: Time.now.to_i + 5,
            nbf: Time.now.to_i + 2
          }
          token = JWT.encode payload, 'ASECRET', 'HS256'
          return_body = {"token" => token}
          return response(body: {"token" => token}, status: 201)
        rescue JSON::ParserError
          response(status:422)
        rescue TypeError
          response(status:422)
        end
      end
    end

  elsif event["path"] == '/'
    if event["httpMethod"] != "GET"
      response(status: 405)
    elsif event["httpMethod"] == "GET"
      if event["headers"] == '' or event["headers"] == nil or event["headers"]["authorization"] == '' or event["headers"]["authorization"] == nil
        response(status: 403)
      elsif event["headers"]["authorization"][/^Bearer \S+$/] == nil or event["headers"]["authorization"][/^Bearer \S+$/] == ''
        response(status: 403)
      else
        puts "here"
        print(event["headers"]["authorization"])
        begin
          token_ori = event["headers"]["authorization"].split(" ")[1]
          token_decode_arr = JWT.decode token_ori,  'ASECRET', true, { algorithm: 'HS256' }
          data, exp, nbf = token_decode_arr[0]["data"], token_decode_arr[0]["exp"], token_decode_arr[0]["nbf"]
            return response(body: token_decode_arr[0]["data"], status: 200)
        rescue JWT::ImmatureSignature, JWT::ExpiredSignature
          return response(status: 401)
        rescue JWT::DecodeError
          return response(status: 403)
        end
      end
    end
  end
end

def response(body: nil, status: 200)
  {
    body: body ? body.to_json + "\n" : '',
    statusCode: status
  }
end

if $PROGRAM_NAME == __FILE__
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
               'headers' => { 'auTHOrIzation' => "Bearer #{token}",
                              'Content-Type' => 'application/json' },
               'httpMethod' => 'GET',
               'path' => '/'
             })
end