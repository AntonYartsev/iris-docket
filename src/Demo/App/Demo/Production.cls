Class App.Demo.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="App.Demo.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>Portal demo: an HL7 admissions feed with one router and two destinations.</Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="EnsLib.Testing.Service" Category="demo" ClassName="EnsLib.Testing.Service" PoolSize="1" Enabled="true" Foreground="false" Comment="Sends the demo messages" LogTraceEvents="false" Schedule="" />
  <Item Name="Admissions Router" Category="demo" ClassName="App.Demo.Process" PoolSize="1" Enabled="true" Foreground="false" Comment="ADT to the chart, ORU to the lab archive" LogTraceEvents="false" Schedule="" />
  <Item Name="Chart" Category="demo" ClassName="App.Demo.Operation" PoolSize="1" Enabled="true" Foreground="false" Comment="Files admissions against a patient chart" LogTraceEvents="false" Schedule="" />
  <Item Name="Lab Archive" Category="demo" ClassName="App.Demo.Operation" PoolSize="1" Enabled="true" Foreground="false" Comment="Files observations" LogTraceEvents="false" Schedule="" />
</Production>
}

}
