function FindProxyForURL(url, host) {
     // Resolve the URL host to IP
     var hostip = dnsResolve(host);

     // our local URLs or TN don't need a proxy:
     if (isPlainHostName(host) ||
         dnsDomainIs(host, ".cms") ||
         isInNet(hostip, "10.176.0.0",  "255.255.0.0") ||
         isInNet(hostip, "172.18.0.0",  "255.255.0.0"))
     {return "DIRECT";}

     return "PROXY cmsproxy.cms:3128;";
  }
