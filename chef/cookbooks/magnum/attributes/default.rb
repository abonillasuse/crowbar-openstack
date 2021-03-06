# Copyright 2015, SUSE, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default[:magnum][:debug] = false

override[:magnum][:user] = "magnum"
override[:magnum][:group] = "magnum"

default[:magnum][:max_header_line] = 16_384

default[:magnum][:api][:protocol] = "http"

# HA
default[:magnum][:ha][:enabled] = false
# When HAproxy listens on the API port, make service listen elsewhere
default[:magnum][:ha][:ports][:api] = 5611
# pacemaker definitions
default[:magnum][:ha][:api][:op][:monitor][:interval] = "10s"
default[:magnum][:ha][:api][:agent] = "service:openstack-magnum-api"
default[:magnum][:ha][:conductor][:op][:monitor][:interval] = "10s"
default[:magnum][:ha][:conductor][:agent] = "service:openstack-magnum-conductor"

default[:magnum][:cert][:cert_manager_type] = "local"
