#!/bin/bash

## RUN BEFORE THE SCRIPT!!! SETS UP PASSWORDLESS ACCESS TO MASTER NODE
## ssh-agent sh -c 'ssh-add < /dev/null && bash'

# Script to create a new virtualenv, and install all the required software
# inside it
# This should be run on a compute node, not on the master

die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "1 argument required, $# provided"

# TODO - check that the following Debian packages are installed
# atlas, fortran95, git, mercurial

VENV=$HOME/env/$1
NEST_VERSION=2.2.1
NRN_VERSION=7.2
PKG_DIR=$HOME/packages
PKG_URL=file://${PKG_DIR}/
DEV=$HOME/dev
STACKI=$HOME/dev/stack-installer
WITH_MPI=1

##virtualenv --no-site-packages $VENV  # currently can only be run on master, as virtualenv not installed on nodes
source ${VENV}/bin/activate

if [0];
then
#clone repositories
mkdir $DEV/pkg/$1 
ssh ClusterU "cd $DEV/pkg/$1/ ; git clone https://github.com/NeuralEnsemble/python-neo.git neo"
ssh ClusterU "cd $DEV/pkg/$1/ ; git clone  https://github.com/apdavison/PyNN.git pynn"
ssh ClusterU "cd $DEV/pkg/$1/ ; git clone https://github.com/apdavison/parameters.git parameters"
ssh ClusterU "cd $DEV/pkg/$1/ ; git clone -b pynn0.8 https://github.com/antolikjan/mozaik.git mozaik"
ssh ClusterU "cd $DEV/pkg/$1/mozaik ; git clone https://github.com/antolikjan/mozaik-contrib.git contrib"
ssh ClusterU "cd $DEV/pkg/$1/ ; svn co https://neuralensemble.org/svn/NeuroTools/trunk NeuroTools"
ssh ClusterU "cd $PKG_DIR; hg clone https://bitbucket.org/apdavison/lazyarray"
ssh ClusterU "cd $PKG_DIR; hg clone https://bitbucket.org/apdavison/sumatra"

cd $VENV
ln -s lib/python2.7/site-packages pkgs
cd $VENV/pkgs
ln -s $DEV/pkg/$1/neo/neo
ln -s $DEV/pkg/$1/pynn/src pyNN
ln -s $DEV/pkg/$1/NeuroTools/src NeuroTools
ln -s $DEV/pkg/$1/mozaik/mozaik
ln -s $DEV/pkg/$1/parameters/parameters

cd /tmp

#install numpy first as things numexp depens on it even at configuration time
pip install -f $PKG_URL numpy

# install general dependencies
pip install -f $PKG_URL -r $STACKI/requirements_general.txt
# install Neo dependencies
pip install -f $PKG_URL -r $STACKI/requirements_Neo.txt
# install PyNN dependencies
pip install -f $PKG_URL -r $STACKI/requirements_PyNN.txt   # can't install nrnutils until after NEURON installed - need to do a bugfix release
# install Mozaik dependencies
pip install -f $PKG_URL -r $STACKI/requirements_Mozaik.txt 

# install Sumatra dependencies - currently there seem to be problems with yaml
#pip install -f $PKG_URL -r $STACKI/requirements_Sumatra.txt

#############PIP INSTALL lazyarray from git master
pip install -f $PKG_URL file://$PKG_DIR/lazyarray#egg=lazyarray
##################################################

############### PIP INSTALL sumatra from git master
pip install -f $PKG_URL  file://$PKG_DIR/sumatra#egg=sumatra
###################################################


#############installing pysvn
# download, tar xzf
#cd Source
#python setup.py configure --svn-lib-dir=/usr/lib/x86_64-linux-gnu --apr-inc-dir=/usr/include/apr-1.0 --apu-inc-dir=/usr/include/apr-1.0
#make
#mkdir $PKG_DIR/pysvn
#cp pysvn/__init__.py $PKG_DIR/pysvn
#cp pysvn/_pysvn_2_7.so $PKG_DIR/pysvn
###############################


############## MPI4PY ############
if [ $WITH_MPI = 1 ];
then
    pip install --download $PKG_DIR mpi4py==1.3
    cd $PKG_DIR
    tar xzf mpi4py-1.3.tar.gz
    cd mpi4py-1.3
    cp 	$STACKI/test.cfg $PKG_DIR/mpi4py-1.3
    python setup.py build  --mpi=openmpi,test.cfg
    python setup.py install

fi
###############
fi


######################### install NEST
cd $PKG_DIR
if [ ! -d nest-${NEST_VERSION} ];
then
    if [ ! -f nest-${NEST_VERSION}.tar.gz ];
    then
        echo "Downloading NEST"
        wget http://www.nest-initiative.org/download/gplreleases/nest-$NEST_VERSION.tar.gz
    fi
    echo "Unpacking NEST"
    tar xzf nest-${NEST_VERSION}.tar.gz
fi
cd $VENV
mkdir -p build/NEST/${NEST_VERSION}
cd build/NEST/${NEST_VERSION}
if [ $WITH_MPI = 1 ];
then
    echo "Configuring NEST with MPI"
    $PKG_DIR/nest-${NEST_VERSION}/configure --prefix=$VENV --with-gsl --with-mpi=/opt/software/mpi/openmpi-1.6.3-gcc --with-pynest-prefix=$VENV
else
    echo "Configuring NEST without MPI"
    $PKG_DIR/nest-${NEST_VERSION}/configure --prefix=$VENV --with-gsl --with-pynest-prefix=$VENV
fi
echo "Building NEST"
make
make install
##################################


# LETS MAKE SURE WE STORE THE SCRIPT THAT GENERATED THIS ENVIRONMENT
# !!!!!!!!! HACK IT ASSUMES THIS SCRIPT IS IN $DEV
cp -r $STACKI/ $DEV/pkg/$1/

