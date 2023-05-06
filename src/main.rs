use engine;

fn main() {
    pollster::block_on(engine::run());
}
