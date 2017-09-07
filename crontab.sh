# 凌晨2点执行，查找目录下面7天内没有被访问的文件并删除，释放空间
0 2 * * * find /opt/uploads/cache/thumb -atime -7 | xargs rm -rf
0 3 * * * find /opt/tomcat-7-8090/logs -atime -7 | xargs rm -rf
