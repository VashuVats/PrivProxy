{{<<---- NOTES ---->>}}


 The SOCKS request is formed as follows:

        +----+-----+-------+------+----------+----------+
        |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
        +----+-----+-------+------+----------+----------+
        | 1  |  1  | X'00' |  1   | Variable |    2     |
        +----+-----+-------+------+----------+----------+
             CMD
                o  CONNECT X'01'
                o  BIND X'02'
                o  UDP ASSOCIATE X'03'

            ATYP
             o  IP V4 address: X'01'
             o  DOMAINNAME: X'03'
             o  IP V6 address: X'04'

"client side of an application protocol will
use the BIND request only to establish secondary connections after a
primary connection is established using CONNECT"

-----------------------------------------------------------------------------------------


"LD_PRELOAD we can now let our socket_hook.so library get loaded before the standard C libraries, meaning the first occurrence of the socket() function is in our shared library."


// find the next occurrence of the socket() function
    o_socket = dlsym(RTLD_NEXT, "socket");
We use dlsym with RTLD_NEXT from "dlfcn.h" to find the next occurrence of the socket() function and store the location in o_socket. Hence, in our example o_socket can from then on be used to call the original socket() function.



Functions like variables, can be associated with an address in the memory. We call
this a function pointer. A specific function pointer variable can be defined as follows.
 int (*fn)(int,int) ;
Here we define a function pointer fn, that can be initialized to any function that takes
 two integer arguments and return an integer.

fn = &sum;
int x = (*fn)(12,10); /* call to the function through a pointer */ 


----------------------------------------------------------------------------------------

REFERENCE ::: https://datatracker.ietf.org/doc/html/rfc1928
              https://www.trickster.dev/post/understanding-socks-protocol/
              https://youtu.be/yCZJEKAYpF4
              https://fishi.devtail.io/weblog/2015/01/25/intercepting-hooking-function-calls-shared-c-libraries/
              https://linux.die.net/man/

----------------------------------------------------------------------------------------

