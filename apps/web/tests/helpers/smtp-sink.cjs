'use strict';
// Test-only SMTP protocol sink. Loopback, memory only, never relays mail.
const net=require('node:net');
async function smtpSink(){
 const messages=[],sockets=new Set();let reject=false;
 const server=net.createServer(socket=>{
  sockets.add(socket);socket.on('close',()=>sockets.delete(socket));socket.on('error',()=>{});
  socket.setEncoding('utf8');socket.write('220 localhost isolated SMTP sink\r\n');
  let input='',data=false,body='',to='';
  socket.on('data',chunk=>{
   input+=chunk;if(input.length+body.length>128*1024){socket.destroy();return;}
   while(input.includes('\r\n')){
    const end=input.indexOf('\r\n'),line=input.slice(0,end);input=input.slice(end+2);
    if(data){if(line!=='.'){body+=line+'\r\n';continue;}data=false;
     if(reject)socket.write('451 Synthetic temporary rejection\r\n');else{messages.push({to,body});socket.write('250 Accepted by local sink only\r\n');}body='';continue;
    }
    if(/^EHLO /i.test(line))socket.write('250-localhost\r\n250 8BITMIME\r\n');
    else if(/^HELO |^MAIL FROM:/i.test(line))socket.write('250 OK\r\n');
    else if(/^RCPT TO:/i.test(line)){to=line.slice(8).trim();socket.write('250 OK\r\n');}
    else if(/^DATA$/i.test(line)){data=true;socket.write('354 End with dot\r\n');}
    else if(/^QUIT$/i.test(line)){socket.end('221 Bye\r\n');}
    else socket.write('502 Unsupported in isolated sink\r\n');
   }
  });
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 return{messages,port:server.address().port,setReject:value=>{reject=value;},async close(){for(const socket of sockets)socket.destroy();await new Promise(resolve=>server.close(resolve));}};
}
function localTransport(port){
 return options=>require('../../api/node_modules/nodemailer').createTransport({...options,
  host:'127.0.0.1',port,secure:false,requireTLS:false,ignoreTLS:true,auth:undefined,
 });
}
const fixtureEnv={MAIL_ENABLED:'true',MAIL_HOST:'smtp.example.invalid',MAIL_PORT:'587',MAIL_USER:'synthetic',MAIL_PASSWORD:'synthetic-test-only',MAIL_FROM:'sender@example.invalid'};
module.exports={smtpSink,localTransport,fixtureEnv};
