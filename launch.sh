#!/bin/bash

python3 "$invocation_script" $run_arg
retval=$?

if [ $retval -ne 0 ]
	then
		status="error"		
	else
		status="success"
		if [ -e /mm_base/evaluationResult.txt ]
        then
            	evaluationResult="error"
        else
            	evaluationResult="success"
        fi
fi

#Notifying Edge Orchestrator after step execution with metadata & Status
#echo "Notifying Edge Orchestrator after step execution with metadata & Status"
curl -sH "Content-Type: application/json"  --request POST  -d '{"entityNum":"'"$entityNumber"'","run_id":"'"$run_id"'","status":"'"$status"'","evaluationResult":"'"$evaluationResult"'"}'  http://edge_orchestrator:$edge_port/v1/stepContainerResult

