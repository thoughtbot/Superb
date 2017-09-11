run -> (env) {
  request = Rack::Request.new(env)

  case request.path
  when "/app-login"
    Rack::Response.new.tap do |response|
      target = URI("superbdemo://oauth/twitter/token")
      target.query = Rack::Utils.build_query(request.params)
      response.redirect(target.to_s)
    end
  else
    [404, {"Content-Type" => "text/plain"}, ["Resource not found."]]
  end
}
