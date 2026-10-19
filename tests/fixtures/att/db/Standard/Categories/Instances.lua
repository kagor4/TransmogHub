local appName, _ = ...
_.AddEventHandler("OnBuildDataCache", function(categories)
local e,h,i,inst,n,s,q=_.CreateEncounter,_.CreateCustomHeader,_.CreateItem,_.CreateInstance,_.CreateNPC,_.CreateItemSource,_.CreateQuest
categories.Instances=
h(-75,{g={
inst(741,{coords={[232]={{54.1,31.2}}},g={
e(1519,{npcID=12118,g={
s(1001,16800,{f=4}),
i(17000)}}),
h(-12,{
s(1002,16801,{cost={{"g",500000},{"c",1220,5}}})}),
(function(t)if GetCVar("portal")=="EU" then t.u=2 end return t end)(
q(8905,{coords={[87]={{43.5,52.6}}},g={
s(1003,16802,{})}}))}})}})
end)
