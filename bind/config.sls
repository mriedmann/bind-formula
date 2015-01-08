{% from "bind/map.jinja" import map with context %}

include:
  - bind

named_directory:
  file.directory:
    - name: {{ map.named_directory }}
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: 775
    - makedirs: True
    - require:
      - pkg: bind

{% if grains['os_family'] == 'RedHat' %}
bind_config:
  file.managed:
    - name: {{ map.config }}
    - source: 'salt://bind/files/redhat/named.conf'
    - template: jinja
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: {{ salt['pillar.get']('bind:config:mode', '640') }}
    - require:
      - pkg: bind
    - watch_in:
      - service: bind

bind_local_config:
  file.managed:
    - name: {{ map.local_config }}
    - source: 'salt://bind/files/redhat/named.conf.local'
    - template: jinja
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: {{ salt['pillar.get']('bind:config:mode', '644') }}
    - require:
      - pkg: bind
    - watch_in:
      - service: named
{% endif %}

{% if grains['os_family'] == 'Debian' %}
bind_config:
  file.managed:
    - name: {{ map.config }}
    - source: 'salt://bind/files/debian/named.conf'
    - template: jinja
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: {{ salt['pillar.get']('bind:config:mode', '644') }}
    - require:
      - pkg: bind
    - watch_in:
      - service: bind

bind_key_config:
  file.managed:
    - name: {{ map.key_config }}
    - source: 'salt://bind/files/debian/named.conf.key'
    - template: jinja
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: {{ salt['pillar.get']('bind:config:mode', '644') }}
    - require:
      - pkg: bind
    - watch_in:
      - service: bind

bind_local_config:
  file.managed:
    - name: {{ map.local_config }}
    - source: 'salt://bind/files/debian/named.conf.local'
    - template: jinja
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: {{ salt['pillar.get']('bind:config:mode', '644') }}
    - context:
        map: {{ map }}
    - require:
      - pkg: bind
    - watch_in:
      - service: bind

bind_options_config:
  file.managed:
    - name: {{ map.options_config }}
    - source: 'salt://bind/files/debian/named.conf.options'
    - template: jinja
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: {{ salt['pillar.get']('bind:config:mode', '644') }}
    - require:
      - pkg: bind
    - watch_in:
      - service: bind

bind_default_zones:
  file.managed:
    - name: {{ map.default_zones_config }}
    - source: 'salt://bind/files/debian/named.conf.default-zones'
    - template: jinja
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: {{ salt['pillar.get']('bind:config:mode', '644') }}
    - require:
      - pkg: bind
    - watch_in:
      - service: bind

{{ map.log_dir }}:
  file.directory:
    - user: root
    - group: bind
    - mode: 775
    - template: jinja


/etc/logrotate.d/{{ map.service }}:
  file.managed:
    - source: salt://bind/files/debian/logrotate_bind
    - template: jinja
    - user: root
    - group: root
    - template: jinja
    - context:
        map: {{ map }}

{% endif %}

{% for key,args in salt['pillar.get']('bind:zones', {}).iteritems()  -%}
{%- set file = (["db.", key]|join) %}
{% if args['type'] == "master" -%}
{%- set soa = salt['pillar.get']('bind:zones:' + (key|string) + ':soa', {}) %}
{%- set entries = salt['pillar.get']('bind:zones:' + (key|string) + ':entries', {}) %}
zones-{{ file }}:
  file.managed:
    - name: {{ map.named_directory }}/{{ file }}
    - source: 'salt://bind/files/zone.jinja'
    - template: jinja
    - user: {{ salt['pillar.get']('bind:config:user', map.user) }}
    - group: {{ salt['pillar.get']('bind:config:group', map.group) }}
    - mode: {{ salt['pillar.get']('bind:config:mode', '644') }}
    - watch_in:
      - service: bind
    - require:
      - file: {{ map.named_directory }}
    - defaults:
        soa:
          - ttl: 604800
          - ref: 604800
          - ret: 86400
          - exp: 2419200
          - min: 604800
    - context:
        origin: {{ args['origin'] }}
        soa: {{ args['soa'] }}
        entries: {{ args['entries'] }}

{% if args['dnssec'] is defined and args['dnssec'] -%}
signed-{{file}}:
  cmd.run:
    - cwd: {{ map.named_directory }}
    - name: zonesigner -zone {{ key }} {{ file }}
    - prereq:
      - file: zones-{{ file }}
{% endif %}

{% endif %}
{% endfor %}
