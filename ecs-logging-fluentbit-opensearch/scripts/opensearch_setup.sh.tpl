#!/bin/bash
# =============================================================
# OpenSearch OSS ${opensearch_version} 설치 스크립트
# Amazon Linux 2023 / EC2 user_data
# =============================================================
set -euxo pipefail
exec > >(tee /var/log/opensearch_setup.log | logger -t opensearch_setup) 2>&1

# -------------------------------------------------------------
# 0. 변수
# -------------------------------------------------------------
OPENSEARCH_VERSION="${opensearch_version}"
DATA_PATH="${opensearch_data_path}"
OPENSEARCH_PORT="${opensearch_port}"
OPENSEARCH_USER="opensearch"

# -------------------------------------------------------------
# 1. EBS 데이터 볼륨 자동 감지
# -------------------------------------------------------------
# Nitro 기반 인스턴스(t3 등)는 EBS가 /dev/nvme*n1 형태로 노출됨
# 루트 볼륨(nvme0n1)을 제외한 미마운트 블록 디바이스를 데이터 볼륨으로 사용
#
# [주의] aws_volume_attachment는 EC2 부팅 후 별도로 연결되므로
#        user_data 실행 시점에 데이터 EBS가 아직 없을 수 있음 → 최대 5분 대기
EBS_DEVICE=""
echo "데이터 EBS 볼륨 연결 대기 중 (최대 5분)..."
for i in $(seq 1 30); do
  EBS_DEVICE=""
  for dev in /dev/nvme*n1; do
    # 이미 마운트된 디바이스(루트 볼륨 등)는 건너뜀
    if ! lsblk -no MOUNTPOINTS "$dev" 2>/dev/null | grep -q '/'; then
      EBS_DEVICE="$dev"
      break
    fi
  done
  [ -n "$EBS_DEVICE" ] && break
  echo "EBS 볼륨 대기 중... ($i/30, 10초 후 재시도)"
  sleep 10
done

if [ -z "$EBS_DEVICE" ]; then
  echo "ERROR: 데이터용 EBS 볼륨을 찾을 수 없습니다." >&2
  exit 1
fi

echo "데이터 EBS 볼륨 감지: $EBS_DEVICE"

# -------------------------------------------------------------
# 2. EBS 볼륨 포맷 및 마운트
# -------------------------------------------------------------
# 볼륨이 아직 포맷되지 않은 경우에만 mkfs 실행 (재부팅 안전)
if ! blkid "$EBS_DEVICE" > /dev/null 2>&1; then
  mkfs -t xfs "$EBS_DEVICE"
fi

mkdir -p "$DATA_PATH"

# /etc/fstab에 등록 (재부팅 후에도 자동 마운트)
EBS_UUID=$(blkid -s UUID -o value "$EBS_DEVICE")
if ! grep -q "$EBS_UUID" /etc/fstab; then
  echo "UUID=$EBS_UUID $DATA_PATH xfs defaults,nofail 0 2" >> /etc/fstab
fi

mount -a

# -------------------------------------------------------------
# 2. OpenSearch 전용 시스템 계정 생성
# -------------------------------------------------------------
if ! id "$OPENSEARCH_USER" &>/dev/null; then
  useradd -r -s /sbin/nologin "$OPENSEARCH_USER"
fi

chown -R "$OPENSEARCH_USER":"$OPENSEARCH_USER" "$DATA_PATH"

# -------------------------------------------------------------
# 3. 시스템 커널 파라미터 설정 (OpenSearch 권장값)
# -------------------------------------------------------------
cat > /etc/sysctl.d/99-opensearch.conf <<'EOF'
vm.max_map_count = 262144
vm.swappiness = 1
EOF
sysctl --system

# ulimit 설정 (systemd service 파일에서 재설정)
cat > /etc/security/limits.d/99-opensearch.conf <<'EOF'
opensearch  soft  nofile  65536
opensearch  hard  nofile  65536
opensearch  soft  nproc   4096
opensearch  hard  nproc   4096
EOF

# -------------------------------------------------------------
# 4. OpenSearch OSS 2.x RPM 설치 (YUM 저장소)
# -------------------------------------------------------------
cat > /etc/yum.repos.d/opensearch.repo <<EOF
[opensearch-2.x]
name=OpenSearch 2.x repository
baseurl=https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/yum
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://artifacts.opensearch.org/publickeys/opensearch.pgp
EOF

dnf install -y "opensearch-$OPENSEARCH_VERSION"

# -------------------------------------------------------------
# 5. opensearch.yml 설정
# -------------------------------------------------------------
cat > /etc/opensearch/opensearch.yml <<EOF
# OpenSearch OSS $OPENSEARCH_VERSION - Single Node POC
cluster.name: opensearch-cluster
node.name: opensearch-node-1

# 데이터 경로 (EBS 마운트 경로)
path.data: $DATA_PATH
path.logs: /var/log/opensearch

# 네트워크 (모든 인터페이스 바인딩 → SG에서 접근 제어)
network.host: 0.0.0.0
http.port: $OPENSEARCH_PORT

# 싱글 노드 모드 (클러스터 구성 없음)
discovery.type: single-node

# 보안 플러그인 비활성화 (POC, 내부망 전용)
plugins.security.disabled: true
EOF

# opensearch.yml 소유권 설정
chown "$OPENSEARCH_USER":"$OPENSEARCH_USER" /etc/opensearch/opensearch.yml

# -------------------------------------------------------------
# 6. JVM Heap 설정 (t3.medium: 4GB RAM → Heap 2GB)
# -------------------------------------------------------------
cat > /etc/opensearch/jvm.options.d/heap.options <<'EOF'
-Xms2g
-Xmx2g
EOF

# -------------------------------------------------------------
# 7. systemd 서비스 활성화 및 시작
# -------------------------------------------------------------
systemctl daemon-reload

# Amazon Linux 2023은 systemd-sysv-install이 없어 enable이 실패할 수 있음 → symlink로 fallback
systemctl enable opensearch 2>/dev/null || \
  ln -sf /usr/lib/systemd/system/opensearch.service \
         /etc/systemd/system/multi-user.target.wants/opensearch.service

systemctl start opensearch

# -------------------------------------------------------------
# 8. 헬스체크 (최대 3분 대기)
# -------------------------------------------------------------
echo "OpenSearch 기동 대기 중..."
for i in $(seq 1 18); do
  if curl -sf "http://localhost:$OPENSEARCH_PORT/_cluster/health" > /dev/null 2>&1; then
    echo "OpenSearch 정상 기동 완료 (시도: $i)"
    break
  fi
  echo "대기 중... ($i/18)"
  sleep 10
done

echo "OpenSearch 설치 및 설정 완료."
