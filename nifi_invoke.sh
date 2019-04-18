#!/bin/bash

createAndStartProcessGroup(){

	local topicName=$1
	local clientId=$2
	local group_name=$3
	
    #-------------------------------------------------------------
    # Get Root Process Group Number
    #-----------------------------------------
    root_process_group=$(curl -s -X GET http://nifi:8080/nifi-api/flow/process-groups/root | jq '. .processGroupFlow.id' | sed -e 's/^"//' -e 's/"$//')

    
	# Create new process group
    grp_template="curl -s -d '{\"revision\": { \"clientId\":\"CID\",\"version\":0},\"component\":{\"name\":\"group_name\"}}' -H \"Content-Type: application/json\" -X POST http://nifi:8080/nifi-api/process-groups/ROOTGROUP/process-groups"
    new_grp_template=$(echo $grp_template | sed s/CID/$clientId/ | sed s/ROOTGROUP/$root_process_group/ | sed s/group_name/$group_name/)
    root_process_group=$(curl -s -X GET http://nifi:8080/nifi-api/flow/process-groups/root | jq '. .processGroupFlow.id' | sed -e 's/^"//' -e 's/"$//')
    new_process_grp_id=$(eval `echo $new_grp_template` | jq '. .id' | sed -e 's/^"//' -e 's/"$//')

	
	# Add Components
    template="curl -s -d '{\"revision\": { \"clientId\": \"CID\", \"version\": 0 }, \"component\": { \"type\": \"org.apache.nifi.processors.mqtt.ConsumeMQTT\", \"bundle\": { \"group\": \"org.apache.nifi\", \"artifact\": \"nifi-mqtt-nar\", \"version\": \"1.7.1\" }, \"name\": \"ConsumeMQTT\" }}' -H \"Content-Type: application/json\" -X POST http://nifi:8080/nifi-api/process-groups/NEWGRPID/processors"
    template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/ | sed s/CID/$clientId/)
    consumeMqtt=$(eval `echo $template` | jq '. .id' | sed -e 's/^"//' -e 's/"$//')

	

    # Update properties for consumeMqtt processor
    template="curl -s -d '{\"component\":{\"id\":\"CONSUMEMQTTPROCESSOR\",\"name\":\"ConsumeMQTT\",\"config\":{ \"properties\":{\"Broker URI\":\"tcp://mqtt:1883\",\"Client ID\":\"CID\",\"Topic Filter\":\"$topicName\",\"Quality of Service(QoS)\":\"2\",\"Max Queue Size\":\"10\", \"Session state\": \"false\"}},\"state\":\"STOPPED\"},\"revision\":{\"clientId\":\"CID\",\"version\":1}}' -H \"Content-Type: application/json\" -X PUT http://nifi:8080/nifi-api/processors/CONSUMEMQTTPROCESSOR"
    template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/ | sed s/CID/$clientId/ | sed s/CONSUMEMQTTPROCESSOR/$consumeMqtt/g)    
    op=$(eval `echo $template`)

	# Add our custom processor
    template="curl -s -X POST -H \"Content-Type: application/json\" -d '{\"revision\":{\"clientId\":\"CLIENTID\",\"version\":0},\"component\":{\"type\":\"com.acn.aip.edge.nifi.EdgeMMCloudNifiProcessor\",\"bundle\":{\"group\":\"com.acn.aip.edge-analytics\",\"artifact\":\"nifi-cloud-processor\",\"version\":\"1.0\"},\"name\":\"EdgeMMCloudNifiProcessor\",\"position\":{\"x\":332,\"y\":57}}}' http://nifi:8080/nifi-api/process-groups/NEWGRPID/processors"
    template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/g | sed s/CLIENTID/$clientId/)
    customprocessor=$(eval `echo $template` | jq '. .id' | sed -e 's/^"//' -e 's/"$//')

	# config for custom processor
    template="curl -s -X PUT -H \"Content-Type: application/json\" -d'{\"component\":{\"id\":\"CUSTOMPROCESSOR\",\"name\":\"EdgeMMCloudNifiProcessor\",\"config\":{ \"autoTerminatedRelationships\":[\"SUCCESS\"]},\"state\":\"STOPPED\"},\"revision\":{\"clientId\":\"CLIENTID\",\"version\":1}}' http://nifi:8080/nifi-api/processors/CUSTOMPROCESSOR"
    template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/ | sed s/CLIENTID/$clientId/ | sed s/CUSTOMPROCESSOR/$customprocessor/g | sed s/QHOST/$qhost/ | sed s/QPORT/$qport/ | sed s/QNAME/$qname/ | sed s/FNAME/$filename/)
    op=$(eval `echo $template`)

	# Create connection from ConsumeMQTT to custom processor
    template="curl -s -X POST -H \"Content-Type: application/json\" -d '{ \"revision\": { \"clientId\": \"CLIENTID\", \"version\": 0 }, \"component\": { \"name\": \"Message\", \"source\": { \"id\": \"CONSUMEMQTTPROCESSOR\", \"groupId\": \"NEWGRPID\", \"type\": \"PROCESSOR\" }, \"destination\": { \"id\": \"CUSTOMPROCESSOR\", \"groupId\": \"NEWGRPID\", \"type\": \"PROCESSOR\" }, \"selectedRelationships\": [ \"Message\"] } }' http://nifi:8080/nifi-api/process-groups/NEWGRPID/connections"
    template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/g | sed s/CLIENTID/$clientId/ | sed s/CUSTOMPROCESSOR/$customprocessor/ | sed s/CONSUMEMQTTPROCESSOR/$consumeMqtt/)
    connectionid1=$(eval `echo $template` | jq '. .id' | sed -e 's/^"//' -e 's/"$//')

	template="curl -s -X PUT -H \"Content-Type: application/json\" -d '{ \"id\":\"NEWGRPID\", \"state\":\"RUNNING\" }' http://nifi:8080/nifi-api/flow/process-groups/NEWGRPID"

    template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/g)
    eval `echo $template` > /dev/null

	echo "$new_process_grp_id,$consumeMqtt,$customprocessor,$connectionid1,$clientId"

}

startProcessGroup(){
	local new_process_grp_id=$1
	template="curl -s -X PUT -H \"Content-Type: application/json\" -d '{ \"id\":\"NEWGRPID\", \"state\":\"RUNNING\" }' http://nifi:8080/nifi-api/flow/process-groups/NEWGRPID"
	template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/g)
	eval `echo $template` > /dev/null
	if [ "$?" -eq "0" ]
	then
	   echo "Processor group $new_process_grp_id started successfully"
	else
	   echo "Processor group $new_process_grp_id failed to start"
	fi
}

stopProcessGroup(){
	local new_process_grp_id=$1
	template="curl -s -X PUT -H \"Content-Type: application/json\" -d '{ \"id\":\"NEWGRPID\", \"state\":\"STOPPED\" }' http://localhost:8080/nifi-api/flow/process-groups/NEWGRPID"
	template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/g)
	eval `echo $template` > /dev/null
	if [ "$?" -eq "0" ]
	then
	   echo "Processor group $new_process_grp_id stopped successfully"
	else
	   echo "Processor group $new_process_grp_id failed to stop"
	fi
}

cleanProcessGroup(){
	local new_process_grp_id=$1
	local step_id=$2
	local connectionid1=$3
	local connectionid2=$4

	# Delete the queue
	echo "Deleting FetchS3 to custom processor, edge id =$connectionid2"
	template="curl -s -X POST http://localhost:8080/nifi-api/flowfile-queues/CONNECTIONID2/drop-requests"
	template=$(echo $template | sed s/CONNECTIONID2/$connectionid2/ )
	REQUESTID=$(eval `echo $template` | jq '. | .dropRequest | .id' | sed -e 's/^"//' -e 's/"$//')

	template="curl -s -X DELETE http://localhost:8080/nifi-api/flowfile-queues/CONNECTIONID2/drop-requests/REQUESTID"
	template=$(echo $template | sed s/CONNECTIONID2/$connectionid2/ | sed s/REQUESTID/$REQUESTID/ )
	eval `echo $template` 1> /dev/null

	echo "Queue clean from FetchS3 to custom processor"
	# Drop the queue
	template="curl -s -X DELETE -H \"Content-Type: application/json\" http://localhost:8080/nifi-api/connections/CONNECTIONID2?version=1&clientId=CID"
	template=$(echo $template | sed s/CONNECTIONID2/$connectionid2/ | sed s/CID/$clientId/ )
	eval `echo $template` 1> /dev/null
	
    # Connection between ListS3 and FetchS3
	# Delete the queue
	echo "Deleting ListS3 to FetchS3"
	template="curl -s -X POST http://localhost:8080/nifi-api/flowfile-queues/CONNECTIONID1/drop-requests"
	template=$(echo $template | sed s/CONNECTIONID1/$connectionid1/ )
	REQUESTID=$(eval `echo $template` | jq '. | .dropRequest | .id' | sed -e 's/^"//' -e 's/"$//')

	template="curl -s -X DELETE http://localhost:8080/nifi-api/flowfile-queues/CONNECTIONID1/drop-requests/REQUESTID"
	template=$(echo $template | sed s/CONNECTIONID1/$connectionid1/ | sed s/REQUESTID/$REQUESTID/ )
	eval `echo $template` > /dev/null
	echo "Queue clean ListS3 to FetchS3"

	# Drop the queue
	template="curl -s -X DELETE -H \"Content-Type: application/json\" http://localhost:8080/nifi-api/connections/CONNECTIONID1?version=1&clientId=CID"
	template=$(echo $template | sed s/CONNECTIONID1/$connectionid1/ | sed s/CID/$clientId/ )
	eval `echo $template` > /dev/null

	# Now delete the process group
	template="curl -s -X DELETE -H \"Content-Type: application/json\" http://localhost:8080/nifi-api/process-groups/NEWGRPID?version=1&clientId=CID"
	template=$(echo $template | sed s/NEWGRPID/$new_process_grp_id/ | sed s/CID/$clientId/ )
	eval `echo $template` > /dev/null
	if [ "$?" -eq "0" ]
	then
	   echo "Processor group $new_process_grp_id deleted successfully"
	else
	   echo "Processor group $new_process_grp_id failed to be deleted"
	fi
}

#value=$(createProcessGroup 12345 S3DynamicGroup_12345 edge.analytics us-east-1 AKIAILNKX237G2HBDU6A nkoWGLXcf7dQ2tG9Lpw9T5k3NMD+SLmNMQPuyLIk largeFile.txt localhost 5672 edgeQ)
#groupid=$(echo $value | cut -d',' -f1)
#connectionid1=$(echo $value | cut -d',' -f2)
#connectionid2=$(echo $value | cut -d',' -f3)
#startProcessGroup $groupid
#sleep 40
#stopProcessingGroup $groupid
#sleep 40
#cleanUpProcessorGroup $groupid 12345 $connectionid1 $connectionid2


#$1 = nifi process type
#$2 = mqtthost
#$3 = mqttport
#$4 = topic name
#$5 = clientId

case $1 in
 "createAndStartProcessGroup" )
       createAndStartProcessGroup $2 $3 $4
       ;;
 "stopProcessGroup" )
       stopProcessGroup $2
       ;;
 "cleanProcessGroup" )
       cleanProcessGroup $2 $3 $4 $5
       ;;
 * )
       echo "Unknown function"
       ;;
esac
