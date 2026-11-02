#include <hermes/hermes.h>
#include <jsi/jsi.h>

#include <execinfo.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <signal.h>
#include <sys/time.h>
#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

namespace jsi = facebook::jsi;

namespace {

double seconds() {
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

double residentMegabytes() {
    mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, reinterpret_cast<task_info_t>(&info), &count) != KERN_SUCCESS) {
        return -1;
    }
    return info.resident_size / (1024.0 * 1024.0);
}

class FileBuffer : public jsi::Buffer {
  public:
    explicit FileBuffer(const char *path) {
        FILE *file = fopen(path, "rb");
        if (!file) {
            return;
        }
        fseek(file, 0, SEEK_END);
        long length = ftell(file);
        fseek(file, 0, SEEK_SET);
        data_.resize(static_cast<size_t>(length));
        size_t read = fread(data_.data(), 1, data_.size(), file);
        fclose(file);
        data_.resize(read);
    }
    size_t size() const override { return data_.size(); }
    const uint8_t *data() const override { return data_.data(); }

  private:
    std::vector<uint8_t> data_;
};

}

void onCrash(int signal, siginfo_t *info, void *context) {
    void *frames[64];
    int count = backtrace(frames, 64);
    fprintf(stderr, "PROBE signal %d address %p code %d slide %lx\n", signal, info->si_addr, info->si_code,
            static_cast<unsigned long>(_dyld_get_image_vmaddr_slide(0)));
    backtrace_symbols_fd(frames, count, 2);
    _exit(128 + signal);
}

void install(int signal) {
    struct sigaction action;
    memset(&action, 0, sizeof action);
    action.sa_sigaction = onCrash;
    action.sa_flags = SA_SIGINFO;
    sigemptyset(&action.sa_mask);
    sigaction(signal, &action, nullptr);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        return 2;
    }
    install(SIGSEGV);
    install(SIGBUS);
    install(SIGILL);
    double rss0 = residentMegabytes();
    double t0 = seconds();
    fprintf(stderr, "PROBE making runtime\n");
    auto runtime = facebook::hermes::makeHermesRuntime();
    double t1 = seconds();
    fprintf(stderr, "PROBE runtime ready %.3f\n", t1 - t0);
    auto buffer = std::make_shared<FileBuffer>(argv[1]);
    double t2 = seconds();
    if (buffer->size() == 0) {
        printf("PROBE unreadable %s\n", argv[1]);
        return 1;
    }
    double rss1 = residentMegabytes();
    jsi::Value result = runtime->evaluateJavaScript(buffer, "bundle.hbc");
    double t3 = seconds();
    double rss2 = residentMegabytes();
    std::string text = result.isString() ? result.getString(*runtime).utf8(*runtime) : std::string("(not a string)");
    printf("PROBE bytes=%zu makeRuntime=%.3f read=%.3f eval=%.3f rssStart=%.1f rssLoaded=%.1f rssAfterEval=%.1f\n",
           buffer->size(), t1 - t0, t2 - t1, t3 - t2, rss0, rss1, rss2);
    printf("PROBE result %s\n", text.c_str());
    return 0;
}
