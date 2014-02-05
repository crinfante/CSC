#include <stdlib.h>
#include <sstream>
#include <fstream>
#include <time.h>
#include <iostream>
#include <cmath>
#include <limits.h>
#include <float.h>
#include "CLHEP/Random/Randomize.h"




using namespace std;
using namespace CLHEP;

/***********************************/
/*             main.cc             */
/***********************************/
/* author: Man-Hung Tang           */
/* date:30 Aug 2007                */
/* modified: 03/09/07              */
/***********************************/



unsigned* randperm(unsigned n){

  
  
  unsigned i;
  unsigned j;
  unsigned t;
  unsigned *perm;
  perm = new unsigned[n];
  
  
  
    for (i=0;i<n;i++){
      perm[i] = i;
    }

    for (i=0;i<n;i++){
    j = rand()%(n-i)+i;
    t = perm[j];
    perm[j] = perm[i];
    perm[i] = t;
    }
  
  
return perm;
 
}


double *ReadFileMatrix(char *pszFileName ,unsigned *pDimension,char *separator){

ifstream infile;

infile.open(pszFileName);
//   double sumtmp =0 ;
//     for (int i=0;i<(maxocc+1);i++){
//       infile >> pr_occur[i];sumtmp += pr_occur[i];
//     }
    



//FILE*file=fopen(pszFileName,"r");

int c, n=0;

//while((c=fgetc(file))!=EOF){






switch (separator[0]){

	  case '\t':
while (infile.good()){

c=infile.get();
if(c == '\t')
n++;
}
	    break;
          
	  default: 
	
while (infile.good()){
c=infile.get();
if(c == ' ')
n++;
if(c=='\n')
n++;
} 
}


//while (infile.good()){

// c=infile.get();
// if(c == separator)
// n++;
// if(c=='\n')
// n++;
// }

cout<<n<<endl;
if (pDimension!=NULL) *pDimension=n;
double *pMatrix = new double[n];
infile.close();
//infile.seekg(0,ios::beg);
//rewind(file);
infile.open(pszFileName);

for (int i=0;i<n;i++){
 infile  >> pMatrix[i];
}

// cout << pMatrix[0] << endl;
//for(unsigned k=0;k<n;k++)
//fscanf(file, "%4.5f", pMatrix+k);

//fclose(file);
return pMatrix;

}


/***************************/
/*       main routine      */
/***************************/


int main (int argc, char *argv[]){


  
  
  if (argc != 5 && argc != 4){
    cout<<"usage: PWMrandom <inputmatrix> <outputmatrix> <nmatrix> <width>"<<endl;
    return 1;
  }
  
  char *infile = argv[1];

  ofstream outfile;
  char *outfilename = argv[2];
  outfile.open (outfilename);

  istringstream foo(argv[3]);
  unsigned nmat;foo >> nmat; // number of matrices
  
  unsigned width;
  if (argc == 5){
    istringstream foo2(argv[4]);
    foo2 >> width; // width of output PCMs
  }

  unsigned n; // n elements in PCM
  unsigned Wpcm; // with of PCM
  double *PCM=ReadFileMatrix(infile,&n," ");
  cout<<"input"<<endl;

  for(unsigned i=0;i<4;i++){
    for(unsigned j=0;j<n/4;j++){
      cout << PCM[i*n/4+j] <<" ";}
    cout<<endl;
  }
  cout<<endl;

  Wpcm = n/4;
  
  unsigned K;
  cout<<"mixture proportions"<<endl;
  double *pmix=ReadFileMatrix("Dirichlet_mixture_EM_estimation_jaspar_K6_pmix.txt",&K,"\t");
  for(unsigned i=0;i<K;i++){
    cout << pmix[i] <<" ";}
  
  cout<<"\n"<<endl;
  
  unsigned N;
  cout<<"mixture components"<<endl;
  
  double *alpha1=ReadFileMatrix("Dirichlet_mixture_EM_estimation_jaspar_K6_alpha1.txt",&N,"\t");
  for(unsigned i=0;i<4;i++){
    for(unsigned j=0;j<N/4;j++){
      cout << alpha1[i*N/4+j] <<" ";}
    cout<<endl;
  }
  cout<<endl;

  unsigned Njaspar;
  cout<<"matrice lengths"<<endl;
  double *jaspar=ReadFileMatrix("jaspar.lengths",&Njaspar,"\t");
  for(unsigned i=0;i<Njaspar;i++){
    cout << jaspar[i] <<" ";}
  cout<<"\n"<<endl;
  
 
  double * apmix; 
  apmix = new double[K];
  
  for (int i=0;i<K;i++){
    apmix[i] = pmix[i];
  }
  
  for (int l =1;l<K;l++){
    apmix[l]= apmix[l] + apmix[l-1];
  }
  
  unsigned ac;
  double r;
  srand ( time(NULL) );
  r = (double)rand()/((double)(RAND_MAX) + (double)1);//cout<<"r: "<<r<<endl;
  
  for (int l =0;l<K;l++){ // find(rand < ap_align,1)
    //   cout<<apmix[l]<<" ";
    if (apmix[l] > r){ 
      //cout<<"apmix["<<l<<"]:"<<apmix[l]<<endl;
      
      ac= l;
      //  cout<<ac<<endl;
      break; 
    }
    
  }


 
  for (unsigned mat=1;mat<=nmat;mat++){

    if (argc == 4){
      unsigned SampledWpos = (unsigned)floor((double)rand()/((double)(RAND_MAX) + (double)1)*Njaspar);
      //cout<<"selected matrix: "<<SampledWpos<<endl;
      cout<<"sampled width from Jaspar: "<<(unsigned)jaspar[SampledWpos]<<endl;
      width = (unsigned)jaspar[SampledWpos];
    }

    unsigned* Corder;
    Corder = new unsigned[Wpcm];
    Corder = randperm(Wpcm);
    double *PermutedPCM= new double[n];

    //for (unsigned i=0;i<Wpcm;i++){
    // cout<<Corder[i]<<" ";
    //}
    cout<<"permuted PCM"<<endl;

   for(unsigned i=0;i<4;i++){
    for(unsigned j=0;j<Wpcm;j++){
      PermutedPCM[i*Wpcm+j] =PCM[i*Wpcm+Corder[j]];
      cout << PCM[i*Wpcm+Corder[j]] <<" ";}
    cout<<endl;
  }
  cout<<endl;


  double *PWM;
  double *sumcol; 
 PWM = new double[width*4]; 
 sumcol = new double[width];
 for(unsigned j=0;j<width;j++){
   sumcol[j] = 0;
 }
  if (width == Wpcm){ 
    
   
    for(unsigned i=0;i<4;i++){
      for(unsigned j=0;j<width;j++){
	PWM[i*width+j] = PermutedPCM[i*width+j] + alpha1[i*N/4+ac];
	 PWM[i*width+j] = RandGamma::shoot(PWM[i*width+j],1);
         sumcol[j] = sumcol[j] + PWM[i*width+j];
	 //cout << PWM[i*width+j] <<" ";
      }
	 //cout<<endl;
    }
    cout<<">Matrix"<<mat<<endl;
    outfile<<">Matrix"<<mat<<endl;
    for(unsigned i=0;i<4;i++){
      for(unsigned j=0;j<width;j++){
	PWM[i*width+j] = PWM[i*width+j] / sumcol[j];
	cout << PWM[i*width+j] <<" ";
      	outfile << PWM[i*width+j] <<" ";
      }
      cout<<endl;
      outfile<<endl;
    }
    cout<<endl;
    outfile<<endl;
  }else{

      for(unsigned i=0;i<4;i++){
	for(unsigned j=0;j<width;j++){
	  PWM[i*width+j] = PermutedPCM[i*width+(unsigned)floor((double)rand()/((double)(RAND_MAX) + (double)1)*width)] + alpha1[i*N/4+ac];
	  //cout << PWM[i*width+j] <<" ";
	  PWM[i*width+j] = RandGamma::shoot(PWM[i*width+j],1);
	  sumcol[j] = sumcol[j] + PWM[i*width+j];
	  //cout << "("<<PWM[i*width+j]<<")" <<" ";
	}
	//cout<<endl;
      }
      cout<<">Matrix"<<mat<<endl;
      outfile<<">Matrix"<<mat<<endl;

      for(unsigned i=0;i<4;i++){
	for(unsigned j=0;j<width;j++){
	  PWM[i*width+j] = PWM[i*width+j] / sumcol[j];
	  cout << PWM[i*width+j] <<" ";
	  outfile << PWM[i*width+j] <<" ";
	}
	cout<<endl;
	outfile<<endl;
      }
      cout<<endl;
      outfile<<endl;
  }

  // test RandGamma package
  //double a, lm;
  //a=PWM[0];
   //lm=1;
   //HepRandom::createInstance();
   //double num = RandGamma::shoot(a,lm);
   //   cout<<"randgamma()"<<num<<endl;
 

  }
  outfile.close();  

  return 0;

}
