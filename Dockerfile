FROM ubuntu:latest

# Cài đặt các phần mềm cần thiết
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    openssh-server \
    wget \
    gnupg2 \
    sudo \
    git \
    && apt-get clean

# Thêm kho lưu trữ PostgreSQL và cài đặt PostgreSQL 14 và PostGIS 3
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y postgresql-14 postgresql-14-postgis-3 && \
    apt-get clean

# Tạo thư mục sshd nếu chưa tồn tại
RUN mkdir -p /var/run/sshd

# Cài đặt Miniconda
RUN wget -O Miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda.sh -b -p /opt/miniconda && \
    rm Miniconda.sh

# Thêm Miniconda vào PATH
ENV PATH="/opt/miniconda/bin:$PATH"

# Khởi động Conda init và thêm kênh conda-forge
RUN /opt/miniconda/bin/conda init && \
    conda config --append channels conda-forge

# Tạo môi trường odc_env và cài đặt datacube, matplotlib, gdal
RUN conda create --name odc_env python=3.8 datacube matplotlib gdal -y

# Cài đặt Jupyter vào môi trường ảo
RUN /opt/miniconda/envs/odc_env/bin/pip install jupyter

# Cài đặt deafrica_tools từ GitHub
RUN /bin/bash -c "source /opt/miniconda/bin/activate odc_env && pip install git+https://github.com/digitalearthafrica/deafrica-tools.git"

# Kích hoạt môi trường conda
RUN echo "source /opt/miniconda/bin/activate odc_env" >> ~/.bashrc
ENV PATH="/opt/miniconda/envs/odc_env/bin:$PATH"

# Khởi động PostgreSQL và tạo database nếu chưa tồn tại
RUN service postgresql start && \
    su - postgres -c "if ! psql -lqt | cut -d \| -f 1 | grep -qw datacube; then createdb datacube; fi"

# Sao chép tệp cấu hình và tệp metadata vào container
COPY .datacube.conf /root/.datacube.conf
COPY metadata-types-deafrica-data.odc-type.yaml /root/metadata-types-deafrica-data.odc-type.yaml
COPY products-deafrica-data.odc-product.yaml /root/products-deafrica-data.odc-product.yaml
COPY ls8_sr_BenTre.ipynb /root/ls8_sr_BenTre.ipynb
COPY ls8_sr_DEA.ipynb /root/ls8_sr_DEA.ipynb

# Thiết lập biến môi trường để Datacube sử dụng tệp cấu hình
ENV DATACUBE_CONFIG_PATH=/root/.datacube.conf

# Cấu hình SSH
RUN echo 'root:password' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

EXPOSE 22 8888

# Khởi động SSH
CMD ["/usr/sbin/sshd", "-D"]
