(function(){


  function bridge_to_parent(){

    // Attempt to link to parent window or if top level window, attempt to
    // connect back to the host we loaded from
    //
    let forward=[".*"];
    try {
      if(window.self !== window.top){
        //Inside an iframe;
        window.parent_bridge=new uSACFastPackBrokerBridgeFrame(broker, forward, window.top);
      }
      else {
        // We are the top level 
        let ws=new WebSocket("/ws");
        window.parent_bridge=new uSACFastPackBrokerBridgeWS(broker, forward, ws);
      }
      
    }
    catch(e){
      // Cross origin restrictions, we are likely a iframe
      //window.parent_bridge=new uSACFastPackBrokerBridgeFrame(broker, forward, window.top);
    }
  }


  function run(){
    //Create a new broker if needed
    window.broker||=new uSACFastPackBroker();

    console.log("-=-==-=- FIRST LISTEN");
    broker.listen(undefined, "test", (msg)=>{
      console.log("--GOT Message TEST, with value", msg);
    });

    let cbb=(msg)=>{
      console.log("--GOT Message TEST AGAIN, with value", msg);
    };

    console.log("-=-==-=- SECOND LISTEN");
    broker.listen(undefined, "test", cbb);

    broker.broadcast(undefined, "test", "data goes here");

    console.log("Doing broadcast");
    broker.broadcast(undefined, "test", "data goes here");

    console.log("Doing IGNORE");
    broker.ignore(undefined, "test", cbb);

    console.log("Doing broadcast after ignore");
    broker.broadcast(undefined, "test", "data goes here");


    bridge_to_parent();
    



    let encoder=new TextEncoder();

    //broker.listen(undefined, "test", parent_bridge);

    let t=setInterval(()=>{
      let data= encoder.encode("test data");
      console.log("Sending data ", data);
      broker.broadcast(undefined, "test",data);
    }, 1000);

    broker.listen(undefined, "return", (data)=>{
      console.log(data);
    });
  }

  if (typeof module === "object" && module && typeof module.exports === "object") {
    // Node.js
    module.exports =run;
  }
  else {
    // Global object
    window.uSACFastPackBrokerTest=run;
  }
}
)();



