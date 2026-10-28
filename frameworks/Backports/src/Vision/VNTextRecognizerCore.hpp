#ifndef REVENANT_VISION_TEXT_RECOGNIZER_CORE_HPP
#define REVENANT_VISION_TEXT_RECOGNIZER_CORE_HPP

#include <cstdint>
#include <string>
#include <vector>

struct RevenantTextWord {
    std::string text;
    float confidence;
    int left;
    int top;
    int right;
    int bottom;
};

struct RevenantTextLine {
    std::string text;
    float confidence;
    int left;
    int top;
    int right;
    int bottom;
    std::vector<RevenantTextWord> words;
};

struct RevenantTextRequest {
    std::string datapath;
    std::string language;
    std::string userWordsFile;
    bool correction;
    int regionLeft;
    int regionTop;
    int regionWidth;
    int regionHeight;
};

bool RevenantTextRecognize(const uint8_t *gray, int width, int height, const RevenantTextRequest& request,
                           std::vector<RevenantTextLine>& lines, std::string& error);

#endif
