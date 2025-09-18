(function(){

  function run(broker,cb){
    //Create a new broker if needed
    broker||=new uSACFastPackBroker();

    console.log("-=-==-=- FIRST LISTEN");
    broker.listen(undefined, "test", (msg)=>{
      console.log("--GOT Message TEST, with value", msg);
    })
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



    let ws=new WebSocket("/ws");
    ws.binaryType="arraybuffer";

    ws.onopen=()=>{
      broker.listen(undefined, "return", (args)=>{
        //Args are [client_id, [msgs]]
        console.log("RETURN MESAGE", args);
      });

      //let bridge=new uSACFastPackBrokerBridgeWS(broker, ws);
      let bridge=new uSACFastPackBrokerBridge(broker);
      bridge.buffer_out_sub= (data, cb)=>{
        ws.send(data[0]);
        cb  && cb(); // NOTE this is syncrhonous
      };

      ws.onmessage=
        (event)=>{
          //console.log("--- GOT DATA ", event.data);
          bridge.on_read_handler([new Uint8Array(event.data)], undefined); 
        };

      let encoder=new TextEncoder();
      
      broker.listen(undefined, "test", bridge);
      
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

      cb && cb(broker, bridge);
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



