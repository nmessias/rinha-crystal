require "option_parser"
require "http/server"
require "db"
require "pg"
require "json"

DB_CONNECTION = DB.open("postgres://admin:123@127.0.0.1:5432/rinha?max_pool_size=1")
port = 8080

OptionParser.parse do |parser|
  parser.banner = "A HTTP Server for the Rinha de Backend 2024 Q1!"
  parser.on "-p PORT", "--port=PORT", "Port to listen (default: #{port})" do |server_port|
    port = server_port.to_i
  end

  parser.on "-h", "--help", "Show help" do
    puts parser
    exit
  end
end

struct Transacao
  include JSON::Serializable

  property valor : Int32
  property tipo : String
  property descricao : String
  property realizada_em : Time?
end

server = HTTP::Server.new do |context|
  context.response.content_type = "application/json"

  begin
    status_code, body = router(context.request)
  rescue ex : JSON::ParseException
    status_code = 422
  end 

  context.response.status_code = status_code
  context.response.print body
end

def router(request)
  path = request.path

  case request.method
  when "GET"
    if md = /\/clientes\/(\d+)\/extrato.*/.match(path)
      return get_extrato(md[1].to_i)
    end
  when "POST"  
    if md = /\/clientes\/(\d+)\/transacoes.*/.match(path)
      body = request.body.not_nil!.gets_to_end

      return criar_transacao(md[1].to_i, body)
    end
  end 

  return 404, nil
end

def get_extrato(id_cliente)
  extrato = DB_CONNECTION.query_one("SELECT get_extrato(#{id_cliente});", as: {JSON::PullParser?} )

  if extrato.nil?
    return 404, nil
  end  

  return 200, extrato.read_raw
end

def criar_transacao(id_cliente, body)
  params = JSON.parse(body)
  if params["descricao"].nil? || params["tipo"].nil? || params["valor"].nil?
    return 422, nil
  end

  descricao = params["descricao"].as_s?
  tipo = params["tipo"].as_s?
  valor = params["valor"].as_i?

  if valor.nil? || descricao.nil? || descricao.size < 0 || descricao.size > 10 || tipo.nil? || (tipo != "c" && tipo != "d")
    return 422, nil
  end

  code, saldo, limite = DB_CONNECTION.query_one("SELECT * FROM criar_transacao(#{id_cliente}, #{valor}, '#{descricao}', '#{tipo}');", as: {Int32, Int32, Int32} )
  if code == -1
    return 404, nil
  end

  if code == -2
    return 422, nil
  end

  return 200, {"saldo" => saldo, "limite" => limite}.to_json
end

puts "Listening on http://127.0.0.1:#{port}"
server.listen("127.0.0.1", port, reuse_port: true)