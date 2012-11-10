/*
This file implements a class that provides an interface for the GPU
scattering code (interface in gpuscatter.hh). It that takes data in on the 
cpu side, copies it to the gpu, and exposes functions that let you perform 
actions with the GPU.

This class will get translated into python via swig
*/


#include <main.cu>
#include <stdio.h>
#include <vector>
#include <assert.h>
#include <iostream>
#include <fstream>
#include <sstream>

#include <gpuscatter.cu>
#include <gpu_mgr.hh>

using namespace std;


void deviceMalloc( void ** ptr, int bytes) {
    cudaError_t err = cudaMalloc(ptr, (size_t) bytes);
    assert(err == 0);
}


inline ostream& operator<< (ostream &out, const vector<float> &s) {
    for(int i=0; i<s.size(); i++) {
        out << s[i] << " ";
    }
    out << endl;   
    return out;
}


GPUScatter::GPUScatter (int bpg_,      // <-- defines the number of rotations

                        int nQ_,
                        int* h_qx_,    // size: nQ
                        int* h_qy_,    // size: nQ
                        int* h_qz_,    // size: nQ

                        int nAtoms_,
                        int* h_rx_,    // size: nAtoms
                        int* h_ry_,    // size: nAtoms
                        int* h_rz_,    // size: nAtoms
                        int* h_id_,    // size: nAtoms
                        
                        int* h_rand1_, // size: nRotations
                        int* h_rand2_, // size: nRotations
                        int* h_rand3_, // size: nRotations
                        
                        int* h_outQ_   // size: nQ (OUTPUT)
                        ) {
                            
    /* All arguments consist of 
     *   (1) an int pointer to the beginning of the array to be passed
     *   (2) ints representing the size of each array
     */
    
    // unpack arguments
    bpg = bpg_;

    nQ = nQ_;
    h_qx = h_qx_;
    h_qy = h_qy_;
    h_qz = h_qz_;

    nAtoms = nAtoms_;
    h_rx = h_rx_;
    h_ry = h_ry_;
    h_rz = h_rz_;
    h_id = h_id_;

    h_rand1 = h_rand1_;
    h_rand2 = h_rand2_;
    h_rand3 = h_rand3_;

    h_outQ = h_outQ_;
    
    // set some size parameters
    const int tpb = 512;
    int nRotations = tpb*bpg;
    
    // compute the memory necessary to hold input/output
    unsigned int nQ_size = nQ*sizeof(float);
    unsigned int nAtoms_size = nAtoms*sizeof(float);
    unsigned int nAtoms_idsize = nAtoms*sizeof(int);
    unsigned int nRotations_size = nRotations*sizeof(float);

    // allocate memory on the board
    float *d_qx;    deviceMalloc( (void **) &d_qx, nQ_size);
    float *d_qy;    deviceMalloc( (void **) &d_qy, nQ_size);
    float *d_qz;    deviceMalloc( (void **) &d_qz, nQ_size);
    float *d_outQ;  deviceMalloc( (void **) &d_outQ, nQ_size);
    float *d_rx;    deviceMalloc( (void **) &d_rx, nAtoms_size);
    float *d_ry;    deviceMalloc( (void **) &d_ry, nAtoms_size);
    float *d_rz;    deviceMalloc( (void **) &d_rz, nAtoms_size);
    int  *d_id;    deviceMalloc( (void **) &d_id, nAtoms_idsize);
    float *d_rand1; deviceMalloc( (void **) &d_rand1, nRotations_size);
    float *d_rand2; deviceMalloc( (void **) &d_rand2, nRotations_size);
    float *d_rand3; deviceMalloc( (void **) &d_rand3, nRotations_size);

    // copy input/output arrays to board memory
    cudaMemcpy(d_qx, &h_qx[0], nQ_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_qy, &h_qy[0], nQ_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_qz, &h_qz[0], nQ_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_outQ, &h_outQ[0], nQ_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_rx, &h_rx[0], nAtoms_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_ry, &h_ry[0], nAtoms_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_rz, &h_rz[0], nAtoms_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_id, &h_id[0], nAtoms_idsize, cudaMemcpyHostToDevice);
    cudaMemcpy(d_rand1, &h_rand1[0], nRotations_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_rand2, &h_rand2[0], nRotations_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_rand3, &h_rand3[0], nRotations_size, cudaMemcpyHostToDevice);

    // check for errors
    cudaError_t error;
    assert(error == 0);  
}

void GPUScatter::run() {
    // execute the kernel
    kernel<tpb> <<<bpg, tpb>>> (d_qx, d_qy, d_qz, d_outQ, nQ, d_rx, d_ry, d_rz, d_id, nAtoms, d_rand1, d_rand2, d_rand3);
    cudaThreadSynchronize();
    err = cudaGetLastError();
    assert(err == 0);
}

void GPUScatter::retreive() {
    // retrieve the output off the board and back into CPU memory
    // copys the array to the output array passed as input
    cudaMemcpy(&h_outQ[0], d_outQ, nQ_size, cudaMemcpyDeviceToHost);
    cudaThreadSynchronize();
    err = cudaGetLastError();
    if(err != 0) { cout << err << endl; assert(0); }
}

GPUScatter::~GPUScatter() {
    // destroy the class
    cudaFree(array_device);
}