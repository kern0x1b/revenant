#import <Foundation/Foundation.h>

void charon_mlcompute_cases(void);
void charon_mlcompute_layer_cases(void);
void charon_mlcompute_optimizer_cases(void);
void charon_mlcompute_graph_cases(void);
void charon_mlcompute_inference_cases(void);

int main(void)
{
    setbuf(stdout, NULL);
    charon_mlcompute_cases();
    charon_mlcompute_layer_cases();
    charon_mlcompute_optimizer_cases();
    charon_mlcompute_graph_cases();
    charon_mlcompute_inference_cases();
    return 0;
}
