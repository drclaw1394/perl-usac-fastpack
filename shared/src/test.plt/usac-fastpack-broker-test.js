(function(){

  function run(){
    window.broker=new uSACFastPackBroker();

    console.log("-=-==-=- FIRST LISTEN");
    broker.listen("test", (msg)=>{
      console.log("--GOT Message TEST, with value", msg);
    })
    let cb=(msg)=>{
      console.log("--GOT Message TEST AGAIN, with value", msg);
    };
    console.log("-=-==-=- SECOND LISTEN");
    broker.listen("test", cb);

    broker.broadcast("test", "data goes here");
    
    console.log("Doing broadcast");
    broker.broadcast("test", "data goes here");

    console.log("Doing IGNORE");
    broker.ignore("test", cb);

    console.log("Doing broadcast after ignore");
    broker.broadcast("test", "data goes here");





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
