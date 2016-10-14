###
This server response to ui on a /vizc end point and returns queried JSON as reponse
###
express = require 'express'
bodyparser = require 'body-parser'
varz = require 'express-varz'
conf = require 'rainier/conf'
path = require 'path'
morgan = require 'morgan'
conf = require 'rainier/conf'
{HTTP_PREFIX} = conf.get()

server = express()
server.use varz.trackExpressResponses()
server.use bodyparser.json limit: '5mb'
server.use bodyparser.urlencoded extended: true

app = express()

for route, configFn of require './routes'
  do (route, configFn) ->
    router = express.Router()
    configFn router, app
    app.use route, router

app.use '/dist', express.static 'dist'
#app.use(express.static('public'));
assetsPath = /\/assets$/
server.use morgan 'combined',
  skip: (req, res) ->
    assetsPath.test req.baseUrl

app.get '/', (req, res, next) ->
  res.sendFile(path.resolve('dist/index.html'));

server.use HTTP_PREFIX, app

port = conf.get 'vizc_server_port'
varz.setHttpServer server.listen port
console.log "Listening on port: #{port}"
