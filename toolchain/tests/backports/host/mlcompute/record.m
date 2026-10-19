#import <Foundation/Foundation.h>

void revenant_mlcompute_cases(void);
void revenant_mlcompute_layer_cases(void);
void revenant_mlcompute_optimizer_cases(void);
void revenant_mlcompute_graph_cases(void);
void revenant_mlcompute_inference_cases(void);

int main(void)
{
    setbuf(stdout, NULL);
    revenant_mlcompute_cases();
    revenant_mlcompute_layer_cases();
    revenant_mlcompute_optimizer_cases();
    revenant_mlcompute_graph_cases();
    revenant_mlcompute_inference_cases();
    return 0;
}
