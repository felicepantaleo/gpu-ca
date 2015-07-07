/*
 * GPUCA.cu
 *
 *  Created on: Jun 17, 2015
 *      Author: fpantale
 */

#include <cuda.h>
#include <stdlib.h>     /* srand, rand */
#include <time.h>       /* time */
#include <vector>
#include "Cell.h"
#include "CUDAQueue.h"
#include "SimpleHit.h"
#include "PacketHeader.h"
#include <iostream>
#include "eclipse_parser.h"
#include <assert.h>     /* assert */


// Maximum relative difference (par1_A - par1_B)/par1_A for each parameters
constexpr float c_maxDoubletRelDifference[]{0.1, 0.1};
constexpr int c_doubletParametersNum = sizeof(c_maxDoubletRelDifference)/sizeof(c_maxDoubletRelDifference[0]);
constexpr int c_maxCellsNumPerLayer  = 256;
constexpr int c_maxNeighborsNumPerCell = 32;

__inline__
__device__
bool isADoublet(const SimpleHit* __restrict__ hits, const int idOrigin, const int idTarget)
{
	float relEtaDiff = 2*fabs((hits[idOrigin].eta - hits[idTarget].eta)/(hits[idOrigin].eta+hits[idTarget].eta));
	if(relEtaDiff > c_maxDoubletRelDifference[0]) return false;
	float relPhiDiff = 2*fabs((hits[idOrigin].phi - hits[idTarget].phi)/(hits[idOrigin].phi+hits[idTarget].phi));
	if(relPhiDiff > c_maxDoubletRelDifference[1]) return false;

	return true;
}


// this will become a global kernel in the offline CA
template< int maxCellsNum, int warpSize >
__device__ void makeCells (const SimpleHit* __restrict__ hits, CUDAQueue<maxCellsNum,Cell<c_maxNeighborsNumPerCell, c_doubletParametersNum> >& outputCells,
			int hitId, int layerId, int firstHitIdOnNextLayer, int numHitsOnNextLayer, int threadId )
{
	auto nSteps = (numHitsOnNextLayer+warpSize-1)/warpSize;

	for (auto i = 0; i < nSteps; ++i)
	{
		auto targetHitId = i*warpSize + threadId;
		if(targetHitId < numHitsOnNextLayer)
		{
			if(isADoublet(hits, hitId, targetHitId))
			{
				auto cellId = outputCells.push(Cell<c_maxNeighborsNumPerCell, c_doubletParametersNum>(hitId, targetHitId, layerId, outputCells.m_data));
				if(cellId == -1)
					break;

			}

		}

	}

}



__global__ void singleBlockCA (const PacketHeader* __restrict__ packet )
{







}




int main()
{
	constexpr auto numLayers = 5;
	constexpr auto numHitsPerLayer = 100;

	srand (time(NULL));
	std::pair<float, float> range_eta(0.1, 0.3);
	std::pair<float, float> range_phi(0.5, 0.6);

	std::vector<SimpleHit> hitsVector(numLayers*numHitsPerLayer);



	for (auto i = 0; i< numLayers; ++i)
	{
		for(auto j =0; j<numHitsPerLayer; ++j)
		{
			hitsVector[i*numHitsPerLayer + j].eta = range_eta.first + (range_eta.second - range_eta.first)*(static_cast <float> (rand()) / static_cast <float> (RAND_MAX));
			hitsVector[i*numHitsPerLayer + j].phi = range_phi.first + (range_phi.second - range_phi.first)*(static_cast <float> (rand()) / static_cast <float> (RAND_MAX));
			hitsVector[i*numHitsPerLayer + j].layerId = i;
			std::cout << i*numHitsPerLayer + j << " "<<  hitsVector[i*numHitsPerLayer + j].eta << " " << hitsVector[i*numHitsPerLayer + j].phi << " " << hitsVector[i*numHitsPerLayer + j].layerId << std::endl;

		}
	}


	int* host_Packet;
	int* device_Packet;
	auto packetSize = sizeof(PacketHeader<c_maxNumberOfLayersInPacket>) + hitsVector.size()*sizeof(SimpleHit);
	cudaMallocHost((void**)&host_Packet, packetSize);
	cudaMalloc((void**)&device_Packet, packetSize);
	PacketHeader<c_maxNumberOfLayersInPacket>* host_packetHeader = (PacketHeader<c_maxNumberOfLayersInPacket>*)(host_Packet);
	SimpleHit* host_packetPayload = (SimpleHit*)((char*)host_Packet + sizeof(PacketHeader<c_maxNumberOfLayersInPacket>));


	//initialization of the Packet to send to the GPU
	host_packetHeader->size = packetSize;
	host_packetHeader->numLayers = numLayers;
	for(auto i = 0; i<numLayers; ++i)
		host_packetHeader->firstHitIdOnLayer[i] = i*numHitsPerLayer;
	memcpy(host_packetPayload, hitsVector.data(), hitsVector.size()*sizeof(SimpleHit));

	// end of the initialization



	for (auto i = 0; i< numLayers; ++i)
	{
		for(auto j =0; j<numHitsPerLayer; ++j)
		{
			assert(hitsVector[i*numHitsPerLayer + j].eta == host_packetPayload[i*numHitsPerLayer + j].eta);
			assert(hitsVector[i*numHitsPerLayer + j].phi == host_packetPayload[i*numHitsPerLayer + j].phi);
			assert(hitsVector[i*numHitsPerLayer + j].layerId == host_packetPayload[i*numHitsPerLayer + j].layerId);

		}
	}
	cudaMemcpyAsync(device_Packet, host_Packet, packetSize, cudaMemcpyHostToDevice, 0);

	singleBlockCA





	cudaFreeHost(host_Packet);
	cudaFree(device_Packet);

}
