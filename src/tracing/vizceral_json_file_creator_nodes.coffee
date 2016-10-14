redis = require 'redis'
_ = require 'underscore'
conf = require 'rainier/conf'
timeInterval = conf.get 'query_interval'
[host, port] = [conf.get('redis:host'), conf.get('redis:port')]
###
This script will get data from redis and prepare JSON from it which can be consumed by
Vizceral to display pipeline data flow. This script will consider every topic as node
@author manish@moz.com (Manish Ranjan)
###

module.exports = class VizJsonNode
  # This method prepares the JSON and sends it as return as and when requested
  @getJSON: (callback) ->
    lastSavedTime = Date.now() - timeInterval
    redis.createClient(port, host).zrangebyscore 'narrows-tracing', lastSavedTime, Date.now(), (err, allData) ->
      return callback err if err

      [success, errors] = filterDataAndError allData
      topicToCount = getErrorsByTopic errors
      topicToChannelbyId = getTopicToChannelbyId success
      reducedMap = reduceMap topicToChannelbyId
      srcToTarget = getSourceToTarget reducedMap
      entryNode = findEntryNodes srcToTarget
      nodesAll = getNodes srcToTarget, topicToCount
      [srcToTargetNodes, sumDanger, sumNormal]  = getSourceToTargetList srcToTarget, entryNode, topicToCount
      output = prepareJSON nodesAll, srcToTargetNodes, sumDanger, sumNormal
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

  # this function gets the number of time error occured and creates a map based on that
  getErrorsByTopic = (errorData)->
    errorNodeMap = {}
    for key, value in errorData

      node = key.split('|')[1].split(':')[0]
      errorNodeMap[node] or= 0
      errorNodeMap[node]++
    errorNodeMap

  # This function creates a  map of key(traceId=revNo + Date.Now()) to the topic channel communication
  getTopicToChannelbyId = (success) ->
    topicToChannelbyId  = {}
    #for value, index in success
    for key, value in success
      successData = key.split '|'
      data = successData[0..1].join '>'  # Ts:Cs>Td
      keyTrace = successData[2]
      if keyTrace of topicToChannelbyId
        topicToChannelbyId[keyTrace] = "#{topicToChannelbyId[keyTrace]},#{data}"
      else
        topicToChannelbyId[keyTrace] = data
    topicToChannelbyId

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
      [src, target] = key.split '>'
      source = src.split(':')[0]
      outputList.push "#{source}>#{target}##{reducedMap[key]}"
    outputList

  # Ths function prepares the nodeList for adding to JSON finally
  getNodes = (srcToTarget, topicToCount) ->
    resultNodes = []
    filterNodes = []
    resultNodes.push 'narrows'
    for key, value of topicToCount
      resultNodes.push key
    for row in srcToTarget
      [first, rest] = row.split '>'
      resultNodes.push first unless first in resultNodes
      temp = rest.split('#')[0]
      resultNodes.push temp unless temp in resultNodes
    for node in resultNodes
      filterNodes.push node if node.indexOf('-') is -1
    for node in filterNodes
      name: node
      class: 'normal'

  # Ths function prepares the source to target mapping for adding to JSON finally
  getSourceToTargetList = (srcToTarget, entryNode, topicCounts) ->
    entryAndVal = {}
    destTopics = []
    danger = 0
    sumDanger = 0
    normal = 0
    sumNormal = 0
    srcToTargetList = for index, node of srcToTarget
      val = node.split '>'             #  'Ts > Td # count'
      sourceTopic = val[0]
      targetNode = val[1].split '#'
      [destTopic, count] = val[1].split '#'
      destTopics.push destTopic
      if sourceTopic in entryNode
        if sourceTopic of entryAndVal
          count = entryAndVal[sourceTopic] + count
          entryAndVal[sourceTopic] = count
        else
          entryAndVal[sourceTopic] = count
      danger = parseInt(topicCounts[destTopic], 10) if topicCounts[destTopic]
      sumDanger += danger;
      normal = parseInt(count, 10)
      sumNormal += normal
      source: sourceTopic
      target: destTopic
      metrics:
        danger: topicCounts[destTopic]
        normal: count
      class: 'normal'

    #Handling failure of external request directly to some topic . e.g store_to_s3, publish_to_fremont
    for key, value of topicCounts
      entryAndVal[key] = value unless key in destTopics

    srcToTargetEntry = for node, index of entryAndVal
      danger = parseInt(topicCounts[destTopic], 10) if topicCounts[destTopic]
      sumDanger += danger;
      normal = parseInt(index, 10)
      sumNormal += normal;
      source: 'narrows'
      target: node
      metrics:
        danger: topicCounts[node]
        normal: index
    [srcToTargetList.concat(srcToTargetEntry), sumDanger, sumNormal]

  # This method find all the entrypoint from narrows
  findEntryNodes = (srcToTarget) ->
    endNodes = []
    startNodes = []
    for key, value of srcToTarget
      if value in endNodes
        continue
      else
        endNodes.push value.split('>')[1].split('#')[0]  # 'Ts > Td # count' , td to push

    for key, value of srcToTarget
      tempNode = value.split('>')[0]
      if tempNode in endNodes
        continue
      else
        startNodes.push tempNode unless tempNode in startNodes
    startNodes

  # This function creates the source to target map which gets consumed to build required JSON for vizceral
  prepareJSON = (nodesAll, srcToTargetNodes, sumDanger, sumNormal) ->
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
        nodes: nodesAll
        connections: srcToTargetNodes
      ]
      connections: [
        source: "INTERNET",
        target: "NARROWS",
        metrics: {
          normal: sumNormal
          danger: sumDanger
        }
        notices:[]
        class: 'normal'
      ]
    output
