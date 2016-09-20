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
      mapOfTopicToCount = getErrorMapOfTopicToCount errors
      traceIdToTopicChannel = getTopicToChannelbyId success
      reducedMap = reduceMap traceIdToTopicChannel
      srcToTarget = getSourceToTarget reducedMap
      entryhead = findEntryHeads srcToTarget
      nodeList = getNodeList srcToTarget
      srcToTargetList = getSourceToTargetList srcToTarget, entryhead, mapOfTopicToCount
      output = prepareJSON nodeList, srcToTargetList
      callback null, output

  # this function filters data and error data in two different lists based on the length of incoming data
  filterDataAndError = (allData) ->
    ###
    Two kind of data 1. success 2. error
    1.<Tsource:Csource|Tdestination| rev-id-| Date.now() to keep it unique
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
      dataArray = key.split('|')[0..1].join('>')
      key_trace = key.split('|')[2]
      if key_trace of traceIdToTopicChannel
        traceIdToTopicChannel[key_trace] = traceIdToTopicChannel[key_trace] + "," + dataArray
      else
        traceIdToTopicChannel[key_trace] = dataArray
    traceIdToTopicChannel

  # This function reduces the map by bringing in count for repetition
  reduceMap = (traceIdToTopicChannel) ->
    reducedMap = {}
    for key, value of traceIdToTopicChannel
      arrayOfTC = value.split(',')
      for item, index in arrayOfTC
        if arrayOfTC[index] of reducedMap
          reducedMap[item]++
        else
          reducedMap[item] = 1
    reducedMap

  # This function prepares output list src>targer>#count
  getSourceToTarget = (reducedMap) ->
    size = _.keys(reducedMap).length
    outputList = []
    for value, index of reducedMap
      [src, trg] = value.split('>')
      source = src.split(':')[0]
      target = trg
      outputList.push(source+'>'+target+'#'+reducedMap[value])
    outputList

  # Ths function prepares the nodeList for adding to JSON finally
  getNodeList = (srcToTarget) ->
    resultNodes = []
    resultNodes.push('narrows')
    for row in srcToTarget
      [first, rest] = row.split('>')
      if first not in resultNodes
        resultNodes.push(first)
      if rest.split('#')[0] not in resultNodes
        resultNodes.push(rest.split('#')[0])
    for node in resultNodes
      name: node
      class: 'normal'

  # Ths function prepares the source to target mapping for adding to JSON finally
  getSourceToTargetList = (srcToTarget, entryhead, mapOfTopicToCount) ->
    mapOfEntryAndVal = {}
    srcToTargetList = for index, node of srcToTarget
      val = node.split('>')
      targetNode = val[1].split('#')
      if val[0] in entryhead
        if val[0] of mapOfEntryAndVal
          count = mapOfEntryAndVal[val[0]] + targetNode[1] * 100
          mapOfEntryAndVal[val[0]] = count
        else
          mapOfEntryAndVal[val[0]] = targetNode[1] * 100
      source: val[0]
      target: targetNode[0]
      metrics:
        danger: mapOfTopicToCount[targetNode[0]] * 100
        normal: targetNode[1] * 100
      class: 'normal'
    srcToTargetEntry = for node, index of mapOfEntryAndVal
      source: 'narrows'
      target: node
      metrics:
        danger: 0
        normal: index
    srcToTargetList.concat(srcToTargetEntry)

  # This method find all the entrypoint narrows
  findEntryHeads = (srcToTarget) ->
    endNodesList = []
    startNodeList = []
    for index, node of srcToTarget
      if node in endNodesList
        continue
      else
        endNodesList.push(node.split('>')[1].split('#')[0])
    for index, node of srcToTarget
      tempNode = node.split('>')[0]
      if tempNode in endNodesList
        continue
      else
        if tempNode not in startNodeList
          startNodeList.push(tempNode)
    startNodeList

  # This function creates the source to taget map which gets consumed to build required JSON for vizceral
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
