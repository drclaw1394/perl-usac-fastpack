(function(){
  "use strict";
// Broker for fastpack messages

class HustleTable {

  constructor(){

    this.default={matcher: undefined, value: [function(){}, undefined], type:'exact'};// Default entry
    this.table=[];
    this.cache={};

    this.dispatcher=(input)=>{

      //Check the cache first
      let results=[];
      let cached=this.cache[input];
      if(cached){
        //Found return the value
        for(let i=0; i<cached.length; i++){
          results.push(cached[i]);
        }
        
      }
      else{
        for(let i=0; i<this.table.length; i++){
          let entry=this.table[i];
          //console.log(entry);
          if(entry.type == "exact"){
            if(entry.matcher == input){
              (this.cache[input]||=[]).push(entry, undefined);
              results.push(entry, undefined);
            }
          }
          else if(entry.type == 'begin'){
            if(input.startsWith(entry.matcher)){
              (this.cache[input]||=[]).push(entry, undefined);
              results.push(entry, undefined);
            }
          }
          else if(entry.type == undefined){
          //console.log("Entryin ht is ", entry);
            let strings=entry.matcher.exec(input);
            if( strings != null){
              strings.shift();  // Remove matching string to leave the captures
              (this.cache[input]||=[]).push(entry, strings);
              results.push(entry, undefined);
            }
          }
        }

        //Default if nothing found already
        if(results.length==0){
          // default matcher... is exact 
          (this.cache[input]||=[]).push(this.default, undefined);
          results.push(this.default, undefined);
        }
      }

      return results;
    };
  }


}



class uSACFastPackBrokerBridge {
  constructor(broker){

    broker||=new uSACFastPackBroker();
    this.broker=broker;

    // rx ns converts inboud codes to ids from remote 
    this.rx_namespace=fastpack.create_namespace();
    
    // rx ns converts outboud ids to codes before sent to remote
    this.tx_namespace=fastpack.create_namespace();


    // This is called internally update external sinks
    this.buffer_out_sub=undefined;


    this.forward_message_sub= (arr, cb)=>{
    //console.log("Top of forward message sub");
      let source=arr.shift();
      let inputs=arr[0];


      let arg={buffer:undefined, inputs:undefined, ns:this.tx_namespace};
      let _inputs=[];
      for(let i=0;i<inputs.length;i+=2){

        let msg=inputs[i];
      //console.log("process message: ", msg);
        if(msg.id==0){
          msg.payload= fastpack.encode_meta_payload(msg.payload);
        }
        _inputs.push(msg);
        //arg.inputs=[msg];
      }
      arg.inputs=_inputs;
      fastpack.encode_message(arg);

    //console.log("Buffer is ", arg.buffer);
      
      this.buffer_out_sub([arg.buffer], cb);
    };

    

    // ONREAD is used to take data incomming and appedn to internal buffer
    // deserialising is done and broker dispatcher is called with parsed
    // messages

    this.on_read_handler=(arr, cb)=>{

      let args={buffer:undefined, outputs:[], ns:this.rx_namespace};
      args.buffer=arr[0];

      fastpack.decode_message(args);
    //console.log("DECODED OUTPUTS", args.outputs);
      for(let i=0; i <args.outputs.length; i++){
        let msg=args.outputs[i];
        if(msg.id == '0'){
          msg.payload=fastpack.decode_meta_payload(msg.payload);
          if(msg.payload.listen){
            msg.sub=this.forward_message_sub;
          }

          if (msg.payload.ignore){
            msg.sub=this.forward_message_sub;
          }
          //TODO: Possible remote listen.. 


        }
      }

      this.broker.dispatcher([this.source_id, args.outputs], cb); 

    };
    
  }
  close(){
    let dispatch=this.broker.dispatcher;
    let obj={ignore: { source: this.source_id, sub: this.forward_message_sub, force:"matcher source"}};
    dispatch([this.source_id,[{ time: Date.now(), id: 0, payload: obj}]]);
  }
}


class uSACFastPackBrokerBridgeWS extends uSACFastPackBrokerBridge{

  constructor(broker, forward, ws){
    super(broker);

    this.ws=ws;
    this.forward=forward; //Pairs of  matcher and type in flattend array

    ws.binaryType="arraybuffer";

    ws.addEventListener("open", ()=>{


      this.buffer_out_sub= (data, cb)=>{
        ws.send(data[0]);
        cb  && cb(); // NOTE this is syncrhonous
      };

      ws.addEventListener("message", 
        (event)=>{
          this.on_read_handler([new Uint8Array(event.data)], undefined); 
        });

      
      ws.addEventListener("close",(event)=>{
        console.log("WEBSOCKET CLOSED");
        clearInterval(t);
        this.close();

        ws=undefined;
      });

      // Setup default forwarding
      if(this.forward){
        for(let i=0;i<this.forward.length; i+=2){
          this.broker.listen(undefined, this.forward[i], this);
        }
      }

    });
  }
}

class WebSocketBP extends WebSocket {
  constructor(url, protocols){

    super(url,protocols);

    this.promise;
    this.resolver;
    this.rejecter;
    this.cbs=[];


    this.pending_byte_count=0;
    this.pending_limit=4096*128;

    //Add an on message handler. to listen for UUID of this socket
    this.addEventListener("message", (event)=>{
      if(event.data.length==0){
        //An empty message was received. THis means the far end  has indicated the send bytes is half of max
        this.pending_byte_count-=(this.pending_limit/2);

        //Execute any callbacks saved
        for(let i=0;i<this.cbs.length;i++){
          try {
            cbs[i]();
          }
          catch(e){
            console.log("Error doing WebSocketPB callback");
          }
        }
        this.resolver(); 
        this.promise=undefined;
      }
    });

    this.addEventListener("error", (event)=>{
        //An empty message was received. THis means the far end  has indicated the send bytes is half of max
        this.pending_byte_count=0;
        this.rejecter(); 
        this.promise=undefined;
      }
    );

    this.addEventListener("close", (event)=>{
        //An empty message was received. THis means the far end  has indicated the send bytes is half of max
        this.pending_byte_count=0;
        this.promise=undefined;
      }
    );

    this.addEventListener("open", (event)=>{
        //An empty message was received. THis means the far end  has indicated the send bytes is half of max
        this.pending_byte_count=0;
        this.promise=undefined;
      }
    );

  }

  send_cb(data, cb){
    //Want to make sure the queued memory usage remains low. 
    this.pending_byte_count+=data.length;
    //Check the acknowledgements packet count
    super.send(data);
  
    if(this.pending_byte_count < this.pending_limit){
      // Do callback for more data
      cb  && cb();
    }
    else {
      // message event with 0 size message is needed
      this.cbs.push(cb);
    }
  }

  send(data){
    this.pending_byte_count+=data.length;
    super.send(data);
    if(this.pending_byte_count < this.pending_limit){
        return Promise.resolve();
    }
    else {
      if(this.promise==undefined){
        this.promise=new Promose((resolve, reject)=>{
          this.resolver=resolve;
          this.rejecter=reject;
        });
        return this.promise;
      }
    }
  }
}





class uSACFastPackBroker {
    constructor(){
      this.uuid=uuid4();
      this.default_source_id=uuid4();
      this.ht=new HustleTable();


      this.dispatcher=(inputs)=>{
        let source=inputs[0];
        let messages=inputs[1];
        //console.log("broker dispatch", source, messages);

        for(let i=0; i< messages.length; i++){
          let msg=messages[i];
          // Do look up of message id in table
        ///console.log("id for lookup it  ", msg.id);
        //console.log("Payload for lookup it  ", msg.payload);
          let entries=this.ht.dispatcher(msg.id); //this.lookup

          for(let j=0; j< entries.length; j+=2){
            let e=entries[j];
            let c=entries[j+1];
          //console.log("matched entry", e, c);

            for(let k=0; k< e.value.length; k+=2){
              let sub=e.value[k];
              let source_id=e.value[k];
              if((source_id==undefined) || (source!= source_id)){
                sub([source,[msg ,c]]);
              }
            }
          }
        }
      };
      

      this.broadcaster_sub=(client_id, kv)=>{
        let msgs=[];
        for(let i=0;i<kv.length; i+=2){
          msgs.push({time: Date.now(), id:kv[i], payload:kv[i+1]});
        }
        this.dispatcher([client_id, msgs]);
        return this;
      };


      this.listener_sub=(source_id,name, sub,type)=>{
        
        if(sub instanceof uSACFastPackBrokerBridge){
          //support direct addition of bridge
            source_id=sub.source_id;
            sub=sub.forward_message_sub;
        }
        //TODO check if sub is function or object
        let object={
          listen:{
            source:   source_id,
            matcher:  name,
            type:     type,
            sub:      sub
          }
        };

        this.dispatcher([source_id, [{time:Date.now(), id:'0', payload:object}]]);

        return this;
      };


      this.meta_handler=(spec)=>{
      //console.log("TOP OF META HANDLER", spec);

        let source_id=spec[0];
        let msgs=spec[1];

        for(let i=0;i<msgs.length; i+=2){
          let msg=msgs[i];
          let object=msg.payload;
          let keys=Object.keys(object);

          for(let j=0; j<keys.length; j++){
            let key=keys[j];
            let value=object[key];

          //console.log("Working with key", key);
            if(key== "listen"){
              let name=value.matcher; 
              let sub= value.sub;
              delete value.sub;
              let type= value.type;


              let org_name=name;
              if(!type){
                name=RegExp(name);
              }
            //console.log("Adding to ht table", name);

              let found=undefined;
              for(let k=0; k<this.ht.table.length; k++){
                let e=this.ht.table[k];

                let pattern_1=e.matcher.source;
                if(pattern_1 == undefined){
                  pattern_1=e.matcher;
                }
                let pattern_2=name.source;
                if(pattern_2 == undefined){
                  pattern_2 =name;
                }

                //if((e.matcher.toString() == name.toString()) && (e.type == type)){
                if((pattern_1 == pattern_2) && (e.type == type)){
                //console.log("adding to EXISTING ht");
                //console.log(e.value);
                  e.value.push(sub, source_id);
                //console.log(e.value);
                  found=true;
                  continue;
                }
              }


              if(!found){
                  let o={matcher:name, value:[sub, source_id], type:type};
              //console.log("adding to ht",o);
                this.ht.table.push(o);

                // Reset cache as new entry will need to tested
              }
            //console.log("HT after listen", this.ht.table);
              this.ht.cache={};

            }
            else if(key=='ignore'){
              let name=value.matcher; 
              let sub= value.sub;
              delete value.sub;
              let type= value.type;

              let force_sub = value.force == "sub";
              let force_source = value.force == "source";
              let force_matcher = value.force == "matcher";

              let org_name=name;
              if(!type){
                name=RegExp(name);
              }

              let found=false;
              for(let k=this.ht.table.length-1; k>=0; k--){
                let e=this.ht.table[k];
              //console.log("ignore looking at ",e)
              //console.log("name and type", name, type);

                let pattern_1=e.matcher.source;
                if(pattern_1 == undefined){
                  pattern_1=e.matcher;
                }
                let pattern_2=name.source;
                if(pattern_2 == undefined){
                  pattern_2 =name;
                }

                //if((e.matcher.toString() == name.toString()) && (e.type == type)){
                if(force_matcher || ((pattern_1 == pattern_2) && (e.type == type))){

                //if((e.matcher.toString() == name.toString()) && (e.type == type)){
                  
              //console.log("ignore name and type match",e)
                  for(let l=e.value.length-2; l >=0; l-=2){
                    if((force_sub || (e.value[l] == sub )) && 
                      (force_source || (e.value[l+1] == source_id))){
                      e.value.splice(l,2);
                      found=1;
                      continue;
                    }
                  }

                  if(e.value.length==0){
                    this.ht.table.splice(k,1);
                  }

                }
              }

              if(found){
                // Reset cache as entires might not match or event exist any longer
                this.ht.cache={};
              }
            }
          }
        }


      };



      this.ignorer_sub=(source_id, name, sub, type)=>{
        let object={
          ignore: {
            source:     source_id,
            matcher:    name,
            type:       type,
            sub:        sub
          }
        };

        this.dispatcher([source_id, [{time:Date.now(), id:'0', payload:object}]]);

        return this;
      };

    //Bootstrap meta handler
    
    this.ht.table.push({matcher:'0', value:[this.meta_handler, this.uuid], type:"exact"});


    }

    broadcast(client, name, value){
      this.broadcaster_sub(client, [name, value]);
    }

    listen(client, name, _sub, type){
      this.listener_sub(client, name, _sub, type);
    }

    ignore(client, name, sub, _sub, type, force){
      this.ignorer_sub(client, name, _sub, type, force);
    }


}



  if (typeof module === "object" && module && typeof module.exports === "object") {
    // Node.js
    //module.exports = uSACFastPackBroker;
  }
  else {
    // Global object
    window.uSACFastPackBroker         = uSACFastPackBroker;
    window.uSACFastPackBrokerBridgeWS = uSACFastPackBrokerBridgeWS;
    window.uSACFastPackBrokerBridge   = uSACFastPackBrokerBridge;
    window.WebSocketPB= WebSocketBP;
  }



})();

