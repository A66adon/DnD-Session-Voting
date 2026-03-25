package ds.dnd.voting.services;

import ds.dnd.voting.dto.TimeSlotStatsDTO;
import ds.dnd.voting.dto.VoteResultDTO;
import ds.dnd.voting.dto.WeekResultDTO;
import ds.dnd.voting.model.TimeSlot;
import ds.dnd.voting.model.Vote;
import ds.dnd.voting.model.VotingWeek;
import ds.dnd.voting.repositories.TimeSlotRepository;
import ds.dnd.voting.repositories.VoteRepository;
import ds.dnd.voting.repositories.VotingWeekRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class VotingService {

    private final VotingWeekRepository votingWeekRepository;
    private final TimeSlotRepository timeSlotRepository;
    private final VoteRepository voteRepository;

    @Value("${app.voting.retention.weeks:10}")
    private int retentionWeeks;

    private static final List<SlotTemplate> SLOT_TEMPLATES = List.of(
            new SlotTemplate(DayOfWeek.MONDAY, LocalTime.of(18, 0)),
            new SlotTemplate(DayOfWeek.TUESDAY, LocalTime.of(18, 0)),
            new SlotTemplate(DayOfWeek.WEDNESDAY, LocalTime.of(18, 0)),
            new SlotTemplate(DayOfWeek.THURSDAY, LocalTime.of(18, 0)),
            new SlotTemplate(DayOfWeek.FRIDAY, LocalTime.of(18, 0)),
            new SlotTemplate(DayOfWeek.SATURDAY, LocalTime.of(10, 0)),
            new SlotTemplate(DayOfWeek.SATURDAY, LocalTime.of(18, 0)),
            new SlotTemplate(DayOfWeek.SUNDAY, LocalTime.of(10, 0)),
            new SlotTemplate(DayOfWeek.SUNDAY, LocalTime.of(18, 0))
    );

    /**
     * Get the current active voting week
     */
    public VotingWeek getCurrentWeek() {
        return votingWeekRepository.findWithTimeSlotsByActiveTrue()
                .orElseGet(this::createNewWeek);
    }

    /**
     * Get detailed results for a specific week including who voted for what
     * Returns null if the week doesn't exist (no error thrown)
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getWeekResults(Long weekId) {
        Optional<VotingWeek> weekOpt = votingWeekRepository.findById(weekId);
        // Week doesn't exist, return null instead of throwing exception
        return weekOpt.map(week -> buildWeekResultDTO(week, true)).orElse(null);
    }

    /**
     * Get results for the current active week
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getCurrentWeekResults() {
        VotingWeek currentWeek = getCurrentWeek();
        return buildWeekResultDTO(currentWeek, true);
    }

    /**
     * Get lightweight results for current week without full voter details.
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getCurrentWeekResultsSummary() {
        VotingWeek currentWeek = getCurrentWeek();
        return buildWeekResultDTO(currentWeek, false);
    }

    /**
     * Build a WeekResultDTO from a VotingWeek
     * Contains vote results, timeslot statistics, and winner determination
     */
    private WeekResultDTO buildWeekResultDTO(VotingWeek week, boolean includeVotes) {
        List<Vote> votes = voteRepository.findVotesByVotingWeek(week.getId());

        Map<Long, Integer> voteCounts = new HashMap<>();
        Map<Long, Integer> preferredVoteCounts = new HashMap<>();

        for (Vote vote : votes) {
            Set<Long> uniqueVotedSlotIds = new HashSet<>();
            for (TimeSlot slot : safeSlots(vote.getTimeslots())) {
                if (uniqueVotedSlotIds.add(slot.getId())) {
                    voteCounts.merge(slot.getId(), 1, Integer::sum);
                }
            }

            Set<Long> uniquePreferredSlotIds = new HashSet<>();
            for (TimeSlot slot : safeSlots(vote.getPreferredTimeSlots())) {
                if (uniquePreferredSlotIds.add(slot.getId())) {
                    preferredVoteCounts.merge(slot.getId(), 1, Integer::sum);
                }
            }
        }

        // Create vote results showing who voted for what
        List<VoteResultDTO> voteResults = includeVotes
                ? votes.stream()
                .map(vote -> new VoteResultDTO(
                        vote.getVoterName(),
                        safeSlots(vote.getTimeslots()).stream()
                                .map(TimeSlot::getDatetime)
                                .sorted()
                                .collect(Collectors.toList()),
                        safeSlots(vote.getPreferredTimeSlots()).stream()
                                .map(TimeSlot::getDatetime)
                                .sorted()
                                .collect(Collectors.toList())
                ))
                .toList()
                : List.of();

        // Calculate statistics for each timeslot
        List<TimeSlotStatsDTO> timeSlotStats = week.getTimeSlots().stream()
                .map(timeSlot -> {
                    int voteCount = voteCounts.getOrDefault(timeSlot.getId(), 0);
                    int preferredCount = preferredVoteCounts.getOrDefault(timeSlot.getId(), 0);

                    return new TimeSlotStatsDTO(
                            timeSlot.getId(),
                            timeSlot.getDatetime(),
                            voteCount,
                            preferredCount,
                            false
                    );
                })
                .sorted(Comparator.comparing(TimeSlotStatsDTO::getDatetime))
                .toList();

        // Determine winners based on weighted vote count (all timeslots with max votes win)
        int maxVotes = timeSlotStats.stream()
                .mapToInt(TimeSlotStatsDTO::getVoteCount)
                .max()
                .orElse(0);

        List<TimeSlotStatsDTO> topByVotes = timeSlotStats.stream()
                .filter(ts -> ts.getVoteCount() == maxVotes && maxVotes > 0)
                .collect(Collectors.toList());

        List<TimeSlotStatsDTO> winners;

        if (topByVotes.size() == 1) {
            winners = topByVotes;
        } else {
            // 3️⃣ Tie-Breaker: Preferred Votes
            int maxPreferred = topByVotes.stream()
                    .mapToInt(TimeSlotStatsDTO::getPreferredVoteCount)
                    .max()
                    .orElse(0);

            winners = topByVotes.stream()
                    .filter(ts -> ts.getPreferredVoteCount() == maxPreferred)
                    .collect(Collectors.toList());
        }

        winners.forEach(ts -> ts.setWinner(true));

        WeekResultDTO result = new WeekResultDTO();
        result.setWeekId(week.getId());
        result.setDeadline(week.getDeadline());
        result.setTimeSlots(timeSlotStats);
        result.setVotes(voteResults);
        result.setWinnerTimeSlots(winners);

        return result;
    }

    /**
     * Manually trigger a week reset (useful for testing)
     */
    @Transactional
    public VotingWeek resetWeek() {
        log.info("Manually triggering week reset");
        return createNewWeek();
    }
    /**
     * Scheduled task to reset the voting week every Monday at midnight
     */
    @Scheduled(cron = "0 0 0 * * MON", zone = "Europe/Berlin")
    @Transactional
    public void scheduledWeekReset() {
        log.info("Scheduled week reset triggered at {}", LocalDateTime.now());
        createNewWeek();
    }

    /**
     * Remove old inactive weeks to keep DB size bounded.
     */
    @Scheduled(cron = "0 15 3 * * MON", zone = "Europe/Berlin")
    @Transactional
    public void cleanupOldData() {
        LocalDate cutoff = LocalDate.now().minusWeeks(Math.max(retentionWeeks, 1));
        List<VotingWeek> oldWeeks = votingWeekRepository.findByActiveFalseAndDeadlineBefore(cutoff);

        for (VotingWeek week : oldWeeks) {
            List<Vote> votes = voteRepository.findVotesByVotingWeek(week.getId());
            voteRepository.deleteAll(votes);
            votingWeekRepository.delete(week);
        }

        if (!oldWeeks.isEmpty()) {
            log.info("Deleted {} old voting weeks older than {}", oldWeeks.size(), cutoff);
        }
    }

    /**
     * Create a new voting week with fresh timeslots
     */
    @Transactional
    protected VotingWeek createNewWeek() {
        LocalDate today = LocalDate.now();

        // Deactivate existing active weeks
        votingWeekRepository.deactivateAll();

        // Calculate deadline: next Sunday
        LocalDate nextSunday = today.with(TemporalAdjusters.next(DayOfWeek.SUNDAY));

        // Create new voting week
        VotingWeek newWeek = new VotingWeek();
        newWeek.setDeadline(nextSunday);
        newWeek.setActive(true);
        newWeek.setTimeSlots(new ArrayList<>());

        VotingWeek savedWeek = votingWeekRepository.save(newWeek);

        // Generate timeslots for the upcoming week (Monday to Sunday after deadline)
        List<TimeSlot> timeSlots = generateTimeSlots(nextSunday, savedWeek);
        timeSlotRepository.saveAll(timeSlots);

        savedWeek.getTimeSlots().addAll(timeSlots);

        log.info("Created new voting week with ID {} and deadline {}", savedWeek.getId(), nextSunday);

        return savedWeek;
    }

    /**
     * Generate timeslots for the week following the deadline
     * Creates slots for each day of the week at common gaming times
     */
    private List<TimeSlot> generateTimeSlots(LocalDate deadline, VotingWeek votingWeek) {
        List<TimeSlot> timeSlots = new ArrayList<>();

        // Start from Monday after the deadline
        LocalDate startDate = deadline.plusDays(1); // Monday after Sunday deadline

        // Generate exactly 9 recurring templates per week.
        for (SlotTemplate template : SLOT_TEMPLATES) {
            LocalDate date = startDate.plusDays(template.dayOfWeek().getValue() - 1L);
            timeSlots.add(new TimeSlot(LocalDateTime.of(date, template.time()), votingWeek));
        }

        log.info("Generated {} timeslots for week starting {}", timeSlots.size(), startDate);

        return timeSlots;
    }

    /**
     * Submit a vote for the current week
     * If the user has already voted, the existing vote will be updated
     */
    @Transactional
    public Vote submitVote(String voterName, List<Long> timeSlotIds, List<Long> preferredTimeSlotIds) {
        VotingWeek currentWeek = getCurrentWeek();

        List<Long> uniqueTimeSlotIds = timeSlotIds == null
                ? List.of()
                : new ArrayList<>(new LinkedHashSet<>(timeSlotIds));

        if (uniqueTimeSlotIds.isEmpty()) {
            throw new RuntimeException("At least one timeslot must be selected");
        }

        // Verify all timeslots belong to current week
        List<TimeSlot> timeSlots = timeSlotRepository.findAllById(uniqueTimeSlotIds);

        if (timeSlots.size() != uniqueTimeSlotIds.size()) {
            throw new RuntimeException("Some timeslots not found");
        }

        boolean allBelongToCurrentWeek = timeSlots.stream()
                .allMatch(ts -> ts.getVotingWeek().getId().equals(currentWeek.getId()));

        if (!allBelongToCurrentWeek) {
            throw new RuntimeException("Some timeslots do not belong to the current voting week");
        }

        // Handle preferred timeslots
        List<TimeSlot> preferredTimeSlots = new ArrayList<>();
        if (preferredTimeSlotIds != null && !preferredTimeSlotIds.isEmpty()) {
            List<Long> uniquePreferredTimeSlotIds = new ArrayList<>(new LinkedHashSet<>(preferredTimeSlotIds));
            // Verify all preferred timeslots are part of the selected timeslots
            if (!new HashSet<>(uniqueTimeSlotIds).containsAll(uniquePreferredTimeSlotIds)) {
                throw new RuntimeException("All preferred timeslots must be among the selected timeslots");
            }
            preferredTimeSlots = timeSlotRepository.findAllById(uniquePreferredTimeSlotIds);

            if (preferredTimeSlots.size() != uniquePreferredTimeSlotIds.size()) {
                throw new RuntimeException("Some preferred timeslots not found");
            }
        }

        // Check if user has already voted for this week
        Optional<Vote> existingVote = voteRepository.findByVoterNameAndVotingWeek(voterName, currentWeek.getId());

        Vote vote;
        if (existingVote.isPresent()) {
            // Update existing vote
            vote = existingVote.get();
            if (vote.getTimeslots() == null) {
                vote.setTimeslots(new ArrayList<>());
            }
            vote.getTimeslots().clear();
            vote.getTimeslots().addAll(timeSlots);
            if (vote.getPreferredTimeSlots() == null) {
                vote.setPreferredTimeSlots(new ArrayList<>());
            }
            vote.getPreferredTimeSlots().clear();
            vote.getPreferredTimeSlots().addAll(preferredTimeSlots);
            log.info("Updated vote for {} with {} timeslots, preferred: {}", voterName, uniqueTimeSlotIds.size(), preferredTimeSlots.size());
        } else {
            // Create new vote
            vote = new Vote(voterName, timeSlots, preferredTimeSlots);
            log.info("Created new vote for {} with {} timeslots, preferred: {}", voterName, uniqueTimeSlotIds.size(), preferredTimeSlots.size());
        }

        return voteRepository.save(vote);
    }

    private List<TimeSlot> safeSlots(List<TimeSlot> slots) {
        return slots == null ? List.of() : slots;
    }

    private record SlotTemplate(DayOfWeek dayOfWeek, LocalTime time) {
    }

}
