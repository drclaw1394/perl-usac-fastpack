(function(){

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



    let ws=new WebSocket("/ws");
    let bridge=new uSACFastPackBrokerBridgeWS(broker, [], ws);


    let encoder=new TextEncoder();

    broker.listen(undefined, "test", bridge);

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



