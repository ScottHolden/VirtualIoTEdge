# Virtual IoT Edge

An ARM template for setting up virtual IoT Edge devices 

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FScottHolden%2FVirtualIoTEdge%2Fmaster%2Ftemplate.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>

## Sample Edge Device:
`mcr.microsoft.com/azureiotedge-simulated-temperature-sensor:1.0`

## Sample Stream Analytics Query:
```
SELECT
    IoTHub.IoTHub.ConnectionDeviceId as DeviceId,
    EventEnqueuedUtcTime as EventTime,
    machine.temperature as MachineTemperature,
    machine.pressure as MachinePressure,
    ambient.temperature as AmbientTemperature,
    ambient.humidity as AmbientHumidity
INTO
    [powerbi]
FROM
    [iothub] TIMESTAMP BY EventEnqueuedUtcTime
```