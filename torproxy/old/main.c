#include "torproxy.h"



int main(int argc , char *argv[]){
    char *host;
    int port , s ;

    struct sockaddr_in sock;

    req *req;
    res *res;

    
    char buf[resSize];

    int success;

    char tmp[512];

    if (argc < 3){
        fprintf(stderr , "Usage: %s <host> <port> \n" ,argv[0]);
        return -1;
    }

    host = argv[1];
    port = atoi(argv[2]);


    s =  socket(AF_INET,SOCK_STREAM,0);
    
    if(s<0){
        perror("socket");

        return -1;
    }

    sock.sin_family = AF_INET;
    sock.sin_port = htons(PROXYPORT);
    sock.sin_addr.s_addr = inet_addr(PROXY);


    if(connect(s,(struct sockaddr *)&sock,sizeof(sock))){
        perror("connect");

        return -1;
    }

    printf("Connected to proxy \n");


    req = request(host,port);

    write(s , req , reqSize);

    memset(buf,0,resSize);

    if(read(s,buf,resSize) < 1){
        perror("read");
        free(req);
        close(s);

        return -1;
    }

    res = (res *)buf;

    success = (res->cmd == 90);

    if(!success){
        fprintf(stderr , "Unable to traverse, error code: %d\n",res->cmd);

                free(req);
        close(s);

        return -1;
    }

    printf("Connection to proxy is successful %s:%d\n",host,port);


    memset(tmp , 0 , 512);
    snprintf(tmp,511, "HEAD / HTTP/1.0\r\n");

    write(s,tmp,strlen(tmp));

    memset(tmp,0,512);
    read(s,tmp,511);
    printf(" '%s' \n",tmp);

    close(s);

    free(req);

    return 0;
}