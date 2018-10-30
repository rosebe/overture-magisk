#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <linux/netlink.h>
#include <sys/socket.h>
#include <linux/rtnetlink.h>
#include <arpa/inet.h>

static int (*__system_property_set)(const char *name, const char *value);
static int (*__system_property_get)(const char *name, char *value);

int perror_and_exit(const char *msg) {
	perror(msg);
	exit(1);
}

void *link_symbol_or_die(const char *symbol) {
	void *result = dlsym(dlopen(NULL ,RTLD_LAZY) ,symbol);
	if ( result == NULL ) {fprintf(stderr ,"%s\n" ,dlerror());exit(1);}
	return result;
}

int open_socket_or_die(void) {
	int result = socket(AF_NETLINK ,SOCK_RAW ,NETLINK_ROUTE);
	if ( result < 0 ) perror_and_exit("open NETLINK socket");

	struct sockaddr_nl netlink_address;

	memset(&netlink_address ,0 ,sizeof(netlink_address));

	netlink_address.nl_family = AF_NETLINK;
	netlink_address.nl_groups = RTMGRP_IPV4_ROUTE;

	if ( bind(result ,(struct sockaddr *) &netlink_address ,sizeof(netlink_address)) < 0 ) perror_and_exit("bind NETLINK socket");

	return result;
}


void exec_watch_gateway_changed(int socket_fd ,void (*callback)(int status ,const char *gateway ,void *cookies) ,void *cookies) {
	ssize_t  received_length = 0;
	char     buffer[4096];

	while ((received_length = recv(socket_fd ,buffer ,sizeof(buffer) ,0)) > 0) {
		struct nlmsghdr *netlink_message_header = (struct nlmsghdr *) buffer;

		while ( NLMSG_OK(netlink_message_header ,received_length) ) {
			struct rtmsg  *route_entry     = (struct rtmsg *)  NLMSG_DATA(netlink_message_header);
			struct rtattr *route_attribute = (struct rtattr *) RTM_RTA(route_entry);
			ssize_t route_attribute_length = RTM_PAYLOAD(netlink_message_header);

			while ( RTA_OK(route_attribute ,route_attribute_length) ) {
				if ( route_attribute->rta_type == RTA_GATEWAY ) {
					char buffer[256];

					inet_ntop(AF_INET ,RTA_DATA(route_attribute) ,buffer ,sizeof(buffer));

					callback(netlink_message_header->nlmsg_type ,buffer ,cookies);
				}

				route_attribute = RTA_NEXT(route_attribute ,route_attribute_length);
			}

			netlink_message_header = NLMSG_NEXT(netlink_message_header ,received_length);
		}
	}
}

void on_gateway_changed(int status ,const char *gateway ,void *cookies) {
	(void)gateway;

	printf("Gateway changed: %s %s\n" ,status == RTM_NEWROUTE ? "add" : "del" ,gateway);

	char *override_dns = (char *)cookies;

	usleep(1000 * 1000);
	
	int  begin_positon      = 1;
	char read_buffer[128]   = {0};
	char format_buffer[128] = {0};
	
	for (; begin_positon <= 4 ; begin_positon++ ) {
		sprintf(format_buffer ,"net.dns%d" ,begin_positon);
		__system_property_get(format_buffer ,read_buffer);
		if ( strcmp(read_buffer ,override_dns) )
			break;
	}
	
	for (int i = 4 ; begin_positon < i ; i-- ) {
		sprintf(format_buffer ,"net.dns%d" ,i - 1);
		__system_property_get(format_buffer ,read_buffer);
		sprintf(format_buffer ,"net.dns%d" ,i);
		__system_property_set(format_buffer ,read_buffer);
	}
	
	__system_property_set("net.dns1" ,override_dns);
}

int main(int argc ,char **argv) {
	if ( argc < 2 ) return 1;

	__system_property_set = (int (*)(const char * ,const char *)) link_symbol_or_die("__system_property_set");
	__system_property_get = (int (*)(const char * ,char *))       link_symbol_or_die("__system_property_get");

	on_gateway_changed(RTM_NEWROUTE ,"0.0.0.0" ,argv[1]);

	int socket_fd = open_socket_or_die();

	exec_watch_gateway_changed(socket_fd ,on_gateway_changed ,argv[1]);

	return 0;
}
