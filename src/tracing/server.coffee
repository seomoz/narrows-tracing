###
This server response to ui on a /vizc end point and returns queried JSON as reponse
###
express = require 'express'
bodyparser = require 'body-parser'
varz = require 'express-varz'
conf = require '../tracing_conf'
path = require('path')

console.log 'Knock Knoock!'
app = express()
app.use varz.trackExpressResponses()
app.use bodyparser.json limit: '1mb'
app.use bodyparser.urlencoded extended: true

for route, configFn of require './routes'
    do (route, configFn) ->
        router = express.Router()
        configFn router, app
        app.use route, router

#app.use express.static '../dist'
app.get '/', (req, res, next) ->
  res.sendFile(path.resolve('dist/index.html'));

port = conf.vizc_server_port
varz.setHttpServer app.listen port
console.log "Listening on port: #{port}"
