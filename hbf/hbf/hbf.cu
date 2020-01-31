#include <device_launch_parameters.h>
#include <iostream>
#include <cstdio> 
#include <cstdlib>   
#include <cuda_runtime.h> 

struct vertice {
    int d;
    int first;
    int indeg;
    int outdeg;
    int lastchangeit;
};

struct edge {
    int s;
    int head;
    int tail;
    int next;
};

int maxlength = 11000000;

__global__ void findedge(struct vertice* v, struct edge* e, int* qv, int* qe,int* numv,int* nume)
{
    int index = threadIdx.x+1+blockIdx.x*blockDim.x;
    int stride = blockDim.x * gridDim.x;
    for (int i = index;i <= (*numv);i = i + stride)
    {
        int u = qv[i];
        for (int j = v[u].first;j != 0;j = e[j].next)
        {
            if (v[e[j].tail].indeg == 1)
            {
                v[e[j].tail].d = min(v[e[j].tail].d, v[e[j].head].d + e[j].s);
            }
            if (v[e[j].tail].outdeg == 0)
            {
                continue;
            }
            atomicExch(&(qe[atomicAdd(nume, 1) + 1]), j);
        }
    }
}

__global__ void release(struct vertice* v, struct edge* e, int* qv, int* qe, int* numv,int* nume,int *it)
{
    int index = threadIdx.x + 1 + blockIdx.x * blockDim.x;
    int stride = blockDim.x * gridDim.x;
    for (int i = index;i <= (*nume);i = i + stride)
    {
        //printf("%d ", i);
        int ee = qe[i];
        //printf("%d ", ee);
        if (v[e[ee].tail].d > v[e[ee].head].d + e[ee].s)
        {
            //atomicExch(&(qv[atomicAdd(numv, 1) + 1]), e[ee].tail);
            atomicMin(&(v[e[ee].tail].d), v[e[ee].head].d + e[ee].s);
            v[e[ee].tail].lastchangeit = *it;
            /*if (*it != v[e[ee].tail].lastchangeit)
            {
                (*numv)++;
                qv[*numv] = e[ee].tail;
                
            }
            */
        }
    }
}

__global__ void findvertice(struct vertice* v, struct edge* e, int* qv, int* qe, int* numv, int* nume, int* it,int n)
{
    int index = threadIdx.x + 1 + blockIdx.x * blockDim.x;
    int stride = blockDim.x * gridDim.x;
    for (int i = index;i <= n;i = i + stride)
    {
        if (v[i].lastchangeit == *it)
        {
            atomicExch(&(qv[atomicAdd(numv, 1) + 1]), i);
        }
    }
}

int main()
{
    int n, m;
    freopen("hbf.txt", "r", stdin);
    scanf("%d %d", &n, &m);
    struct vertice* v;
    struct edge* e;
    int* qv;
    int* qe;
    int* numv;
    int* nume;
    int* it;
    cudaMallocManaged((void**)&v, (n + 1) * sizeof(struct vertice));
    cudaMallocManaged((void**)&e, (m + 1) * sizeof(struct edge));
    cudaMallocManaged((void**)&qv, (n+1) * sizeof(int));
    cudaMallocManaged((void**)&qe, (m+1) * sizeof(int));
    cudaMallocManaged((void**)&numv, sizeof(int));
    cudaMallocManaged((void**)&nume, sizeof(int));
    cudaMallocManaged((void**)&it, sizeof(int));
    for (int i = 1;i <= n;i++)
    {
        v[i].d = maxlength;
        v[i].first = 0;
        v[i].indeg = 0;
        v[i].outdeg = 0;
        v[i].lastchangeit = 0;
    }
    v[1].d = 0;
    for (int i = 1;i <= m;i++)
    {
        e[i].head = 0;
        e[i].tail = 0;
        e[i].next = 0;
        e[i].s = 0;
    }
    *numv = 0;
    *nume = 0;
    //qv[1] = 1;
    for (int i = 1;i <= m;i++)
    {
        int p, q, l;
        scanf("%d %d %d", &p, &q, &l);
        if (p != q)
        {
            v[q].indeg++;
            v[p].outdeg++;
            if (p == 1)
            {
                v[q].d= min(v[q].d, l);
                (*numv)++;
                //printf("%d ", p);
                //printf("%d ", *numv);
                //printf("%d ", qv[*numv]);
                //printf("%d -> ", q);
                qv[*numv] = q;
                //printf("%d %d %d\n", *numv, qv[*numv], q);
            }
            e[i].next = v[p].first;
            v[p].first = i;
            e[i].head = p;
            e[i].tail = q;
            e[i].s = l;
        }
        else
        {
            i--;
            m--;
        }
    }
    freopen("CON", "r", stdin);
    for (*it = 1;(*it) <= n-2;(*it)++)
    {
        dim3 blockSize(256);
        dim3 gridSize1(((*numv) + blockSize.x - 1) / blockSize.x);
        findedge << <gridSize1, blockSize >> > (v, e, qv, qe,numv,nume);
        cudaDeviceSynchronize();
        /*printf("\ne: ");
        for (int j = 1;j <= (*nume);j++)
        {
            printf("%d %d %d %d\n", qe[j],e[qe[j]].head, e[qe[j]].tail, e[qe[j]].s);
        }
        printf("v: ");*/
        *numv = 0;
        dim3 gridSize2(((*nume) + blockSize.x - 1) / blockSize.x);
        release << <gridSize2, blockSize >> > (v, e, qv, qe, numv,nume,it);
        cudaDeviceSynchronize();
        *nume = 0;
        /*for (int j = 1;j <= (*numv);j++)
        {
            printf("%d ", qv[j]);
        }*/
        dim3 gridSize3((n + blockSize.x - 1)/blockSize.x);
        findvertice << <gridSize3, blockSize >> > (v, e, qv, qe, numv, nume, it,n);
        cudaDeviceSynchronize();
        /*printf("\nd: ");
        for (int j = 1;j <= n;j++)
        {
            printf("%d ", v[j].d);
        }*/
        if (*numv == 0)
            break;
        //printf("\n");
    }
    for (int i = 1;i <= m;i++)
    {
        if (v[e[i].tail].outdeg == 0)
        {
            v[e[i].tail].d = min(v[e[i].tail].d, v[e[i].head].d + e[i].s);
        }
    }
    freopen("E:\\大三下\\实验室\\bf_no_cuda\\bf_no_cuda\\hbf_result.txt", "w", stdout);
    for (int j = 1;j <= n;j++)
    {
        printf("%d ", v[j].d);
    }
    cudaFree(v);
    cudaFree(e);
    cudaFree(qv);
    cudaFree(qe);
    cudaFree(numv);
    cudaFree(nume);
    fclose(stdin);
    fclose(stdout);
}