fs = require "fs"
Q = require "q"
Client = require("../model/clients").Client
Keystore = require("../model/keystore").Keystore
logger = require "winston"

config = require '../config/config'
statsdServer = config.get 'statsd'
application = config.get 'application'
SDC = require 'statsd-client'
os = require 'os'

domain = "#{os.hostname()}.#{application.name}.appMetrics"
sdc = new SDC statsdServer

###
# Fetches the trusted certificates, callsback with an array of certs.
###
exports.getTrustedClientCerts = (done) ->
  Keystore.findOne (err, keystore) ->
    done err, null if err
    certs = []
    if keystore.ca?
      for cert in keystore.ca
        certs.push cert.data

    return done null, certs

###
# Gets server options object for use with a HTTPS node server
#
# mutualTLS is a boolean, when true mutual TLS authentication is enabled
###
exports.getServerOptions = (mutualTLS, done) ->
  Keystore.findOne (err, keystore) ->
    if err
      logger.error "Could not fetch keystore: #{err}"
      return done err

    if keystore?
      options =
        key:  keystore.key
        cert: keystore.cert.data
    else
      return done(new Error 'Keystore does not exist')
    
    if mutualTLS
      exports.getTrustedClientCerts (err, certs) ->
        if err
          logger.error "Could not fetch trusted certificates: #{err}"
          return done err, null

        options.ca = certs
        options.requestCert = true
        options.rejectUnauthorized = false  # we test authority ourselves
        done null, options
    else
      done null, options


###
# Koa middleware for mutual TLS authentication
###
exports.koaMiddleware = (next) ->
  startTime = new Date() if statsdServer.enabled
  if this.authenticated?
    yield next
  else
    if this.req.client.authorized is true
      subject = this.req.connection.getPeerCertificate().subject
      logger.info "#{subject.CN} is authenticated via TLS."

      # lookup client by subject.CN (CN = clientDomain) and set them as the authenticated user
      this.authenticated = yield Client.findOne({ clientDomain: subject.CN }).exec()

      if this.authenticated?
        sdc.timing "#{domain}.tlsAuthenticationMiddleware", startTime if statsdServer.enabled
        yield next
      else
        this.authenticated = null
        logger.info "Certificate Authentication Failed: the certificate's common name #{subject.CN} did not match any client's domain attribute, trying next auth mechanism if any..."
        sdc.timing "#{domain}.tlsAuthenticationMiddleware", startTime if statsdServer.enabled
        yield next
    else
      this.authenticated = null
      logger.info "Could NOT authenticate via TLS: #{this.req.client.authorizationError}, trying next auth mechanism if any..."
      sdc.timing "#{domain}.tlsAuthenticationMiddleware", startTime if statsdServer.enabled
      yield next
