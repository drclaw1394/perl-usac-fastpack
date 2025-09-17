(function(){

  function run(){
    window.broker=new uSACFastPackBroker();

    console.log("-=-==-=- FIRST LISTEN");
    broker.listen(undefined, "test", (msg)=>{
      console.log("--GOT Message TEST, with value", msg);
    })
    let cb=(msg)=>{
      console.log("--GOT Message TEST AGAIN, with value", msg);
    };
    console.log("-=-==-=- SECOND LISTEN");
    broker.listen(undefined, "test", cb);

    broker.broadcast(undefined, "test", "data goes here");
    
    console.log("Doing broadcast");
    broker.broadcast(undefined, "test", "data goes here");

    console.log("Doing IGNORE");
    broker.ignore(undefined, "test", cb);

    console.log("Doing broadcast after ignore");
    broker.broadcast(undefined, "test", "data goes here");



    let ws=new WebSocket("/ws");

    ws.onopen=()=>{
      broker.listen("return", (args)=>{
        //Args are [client_id, [msgs]]
        console.log("RETURN MESAGE", args);
      });

      let bridge=new uSACFastPackBrokerBridgeWS(broker, ws);
      let encoder=new TextEncoder();
      //bridge.forward_message_sub(
       // [ws, [{id: "test", time:Date.now(), payload: data}, undefined]], ()=>{});

      broker.listen(ws, "test", bridge);

      let t=setInterval(()=>{
        let data= encoder.encode("test data");
        console.log("Sending data ", data);
        broker.broadcast(undefined, "test",data);
      }, 1000);

      ws.onclose=(event)=>{
        console.log("WEBSOCKET CLOSED");
        clearInterval(t);
        bridge.close();

        ws=undefined;
      };

    }
  }
  if (typeof module === "object" && module && typeof module.exports === "object") {
    // Node.js
    module.exports =run;
  }
  else {
    // Global object
    window.uSACFastPackBrokerTest=run;
  }
})();



