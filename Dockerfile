# Prerequisite 1 - Base Operating System is CentOS 7.
# Design Studio Model Manager uses RHEL 7.3 Maipo for non dockerized MM and CentOS 7 for data scientist's sandbox
# ----------------------------------------------------------------------------
FROM centos:7

# Prerequisite 2 - Install Python 3.4

RUN yum -y update && yum install -y wget epel-release
RUN  yum group install -y "Development Tools"
RUN yum install -y python34 python34-devel

# ----------------------------------------------------------------------------
# Data scientist's own installation stuffs here -
# Example - Install Anaconda and specific packages of it
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Install Edge Analytics specific changes
# ----------------------------------------------------------------------------
# 1. Install pip
# 2. Install mmlibrary dependency libraries (https://agile.digital.accenture.com/browse/EDGEMM-54)
# ----------------------------------------------------------------------------
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN /usr/bin/python3 get-pip.py
RUN /usr/bin/python3 -m pip install setuptools
RUN /usr/bin/python3 -m pip install pandas==0.20.2 scikit-learn[alldeps]==0.18.2
RUN /usr/bin/python3 -m pip install scipy==0.19.1
RUN /usr/bin/python3 -m pip install numpy==1.13.3
RUN /usr/bin/python3 -m pip install JayDeBeApi==1.1.1
RUN /usr/bin/python3 -m pip install paho-mqtt

# ----------------------------------------------------------------------------
# 3. Create specific directory structure necessary for EDGEMM
# ----------------------------------------------------------------------------
RUN mkdir -p /mm_base
RUN mkdir -p /step
WORKDIR /mm_base
COPY ./launch.sh .
COPY ./InfoBean.json .
COPY ./nifi_invoke.sh .

# ----------------------------------------------------------------------------
# The launch.sh file would be provided as part of the release and has to be used by data scientists
# ----------------------------------------------------------------------------
RUN chmod a+x /mm_base/launch.sh
RUN sed -i 's/\r//' /mm_base/launch.sh
RUN chmod +x /mm_base/nifi_invoke.sh
RUN sed -i 's/\r//' /mm_base/nifi_invoke.sh

RUN mkdir /shared_data
RUN mkdir /mmlibrary
WORKDIR /mmlibrary
# ----------------------------------------------------------------------------
# The mmlibrary python installer would be provided as part of the release and has to be used by data scientists
# ----------------------------------------------------------------------------
COPY ./mmlibrary-2.1.tar.gz .

RUN /usr/bin/python3 -m pip install /mmlibrary/mmlibrary-2.1.tar.gz

# 4. The recipe file should be present as a label (case sensitive)
COPY ./Success.py /step/
ENV invocation_script="/step/Success.py"

#    Executed via launch.sh only not directly from python
ENTRYPOINT ["/mm_base/launch.sh"]
