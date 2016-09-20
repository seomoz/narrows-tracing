redis = require('redis')
_ = require 'underscore'
conf = require '../tracing_conf'
timeInterval = conf.query_interval
###
This script will get data from redis and prepare JSON from it which can be consumed by
Vizceral to display pipeline data flow. This script will consider every topic as node
@author manish@moz.com (Manish Ranjan)
###

module.exports = class VizJsonNode
  # This method prepares the JSON and sends it as return as and when requested
  @getJSON: (callback) ->
    lastSavedTime = Date.now() - timeInterval
    redis.createClient().zrangebyscore 'narrows-tracing', lastSavedTime, Date.now(), (err, allData) ->
      return callback err if err

      [success, errors] = filterDataAndError allData
      topicToCount = getErrorMapOfTopicToCount errors
      traceIdToTopicChannel = getTopicToChannelbyId success
      reducedMap = reduceMap traceIdToTopicChannel
      srcToTarget = getSourceToTarget reducedMap
      entryNode = findEntryNodes srcToTarget
      nodeList = getNodeList srcToTarget
      srcToTargetList = getSourceToTargetList srcToTarget, entryNode, topicToCount
      output = prepareJSON nodeList, srcToTargetList
      callback null, output

  # this function filters data and error data in two different lists based on the length of incoming data
  filterDataAndError = (allData) ->
    ###
    Two kind of data 1. success 2. error
    1.<Tsource:Csource|Tdestination| rev-id| Date.now() to keep it unique
    2.<rev-id| Tdestination:Cdestination | Date.now()>
    ###
    errors = []
    success = []
    for key, value of allData
      {length} = value.split '|'
      if length is 3 then errors.push value else success.push value
    [success, errors]

  # this function gets the no of time error occured and creates a map based on that
  getErrorMapOfTopicToCount = (errorData)->
    errorNodeMap = {}
    for key, value in errorData
      node = key.split('|')[1].split(':')[0]
      errorNodeMap[node] or= 0
      errorNodeMap[node]++
    errorNodeMap

  # This function creates a  map of key(traceId=revNo + Date.Now()) to the topic channel communication
  getTopicToChannelbyId = (success) ->
    traceIdToTopicChannel = {}
    #for value, index in success
    for key, value in success
      successData = key.split '|'
      data = successData[0..1].join('>')  # Ts:Cs>Td
      keyTrace = successData[2]
      if keyTrace of traceIdToTopicChannel
        traceIdToTopicChannel[keyTrace] = "#{traceIdToTopicChannel[keyTrace]},#{data}"
      else
        traceIdToTopicChannel[keyTrace] = data
    traceIdToTopicChannel

  # This function reduces the map by bringing in count for repetition
  reduceMap = (traceIdToTopicChannel) ->
    reducedMap = {}
    for key, value of traceIdToTopicChannel
      tcPairs = value.split ','
      for item, index in tcPairs
        if tcPairs[index] of reducedMap
          reducedMap[item]++
        else
          reducedMap[item] = 1
    reducedMap

  # This function prepares output list src>targer>#count
  getSourceToTarget = (reducedMap) ->
    size = _.keys(reducedMap).length
    outputList = []
    for key, value of reducedMap
      [src, trg] = key.split '>'
      source = src.split(':')[0]
      target = trg
      outputList.push("#{source}>#{target}##{reducedMap[key]}")
    outputList

  # Ths function prepares the nodeList for adding to JSON finally
  getNodeList = (srcToTarget) ->
    resultNodes = []
    resultNodes.push 'narrows'
    for row in srcToTarget
      [first, rest] = row.split '>'
      if first not in resultNodes
        resultNodes.push first
      if rest.split('#')[0] not in resultNodes
        resultNodes.push rest.split('#')[0]

    for node in resultNodes
      name: node
      class: 'normal'

  # Ths function prepares the source to target mapping for adding to JSON finally
  getSourceToTargetList = (srcToTarget, entryNode, topicCounts) ->
    entryAndVal = {}
    srcToTargetList = for index, node of srcToTarget
      val = node.split '>'             #  'Ts > Td # count'
      targetNode = val[1].split '#'
      if val[0] in entryNode
        if val[0] of entryAndVal
          count = entryAndVal[val[0]] + targetNode[1] * 100
          entryAndVal[val[0]] = count
        else
          entryAndVal[val[0]] = targetNode[1] * 100
      source: val[0]
      target: targetNode[0]
      metrics:
        danger: topicCounts[targetNode[0]] * 100
        normal: targetNode[1] * 100
      class: 'normal'

    srcToTargetEntry = for node, index of entryAndVal
      source: 'narrows'
      target: node
      metrics:
        danger: 0
        normal: index

    srcToTargetList.concat(srcToTargetEntry)

  # This method find all the entrypoint from narrows
  findEntryNodes = (srcToTarget) ->
    endNodesList = []
    startNodeList = []
    for key, value of srcToTarget
      if value in endNodesList
        continue
      else
        endNodesList.push value.split('>')[1].split('#')[0]  # 'Ts > Td # count' need td to push hence twice split

    for key, value of srcToTarget
      tempNode = value.split('>')[0]
      if tempNode in endNodesList
        continue
      else
        if tempNode not in startNodeList
          startNodeList.push tempNode
    startNodeList

  # This function creates the source to target map which gets consumed to build required JSON for vizceral
  prepareJSON = (nodeList, srcToTargetList) ->
    output =
      renderer: 'global'
      name: 'edge'
      nodes: [
        renderer: 'region'
        name: 'INTERNET'
        class: 'normal'
      ,
        renderer: 'region'
        name: 'NARROWS'
        maxVolume: 5000
        class: "normal"
        updated: Date.now()
        nodes: nodeList
        connections: srcToTargetList
      ]
      connections: [
        source: "INTERNET",
        target: "NARROWS",
        metrics: {
          normal: 5000
          danger: 0
        }
        notices:[]
        class: 'normal'
      ]
    output
